_ = require 'underscore'
path = require 'path'

{AttachmentStore} = require 'mailspring-exports'

Actions = require('../actions').default
DatabaseStore = require('./database-store').default
AccountStore = require('./account-store').default
ContactStore = require('./contact-store').default
MessageStore = require './message-store'
FocusedPerspectiveStore = require('./focused-perspective-store').default

DraftStore = null
DraftHelpers = require('./draft-helpers').default

Thread = require('../models/thread').default
Contact = require('../models/contact').default
Message = require('../models/message').default
Utils = require '../models/utils'

{subjectWithPrefix} = require '../models/utils'
DOMUtils = require '../../dom-utils'

class DraftFactory
  createDraft: (fields = {}) =>
    account = @_accountForNewDraft()
    defaults = {
      body: ''
      subject: ''
      version: 0
      unread: false
      starred: false
      headerMessageId: Utils.generateTempId() + "@" + require('os').hostname()
      from: [account.defaultMe()]
      date: (new Date)
      draft: true
      pristine: true
      accountId: account.id
    }
    Promise.resolve(new Message(Object.assign(defaults, fields)))

  createDraftForMailto: (urlString) =>
    account = @_accountForNewDraft()

    try
      urlString = decodeURI(urlString)

    match = /mailto:\/*([^\?\&]*)((.|\n|\r)*)/.exec(urlString)
    if not match
      return Promise.reject(new Error("#{urlString} is not a valid mailto URL."))

    [whole, to, queryString] = match

    if to.length > 0 and to.indexOf('@') is -1
      to = decodeURIComponent(to)

    # /many/ mailto links are malformed and do things like:
    #   &body=https://github.com/atom/electron/issues?utf8=&q=is%3Aissue+is%3Aopen+123&subject=...
    #   (note the unescaped ? and & in the URL).
    #
    # To account for these scenarios, we parse the query string manually and only
    # split on params we expect to be there. (Jumping from &body= to &subject=
    # in the above example.) We only decode values when they appear to be entirely
    # URL encoded. (In the above example, decoding the body would cause the URL
    # to fall apart.)
    #
    query = {}
    query.to = to

    querySplit = /[&|?](subject|body|cc|to|from|bcc)+\s*=/gi

    openKey = null
    openValueStart = null

    until match is null
      match = querySplit.exec(queryString)
      openValueEnd = match?.index || queryString.length

      if openKey
        value = queryString.substr(openValueStart, openValueEnd - openValueStart)
        valueIsntEscaped = value.indexOf('?') isnt -1 or value.indexOf('&') isnt -1
        try
          value = decodeURIComponent(value) unless valueIsntEscaped
        query[openKey] = value

      if match
        openKey = match[1].toLowerCase()
        openValueStart = querySplit.lastIndex

    contacts = {}
    for attr in ['to', 'cc', 'bcc']
      if query[attr]
        contacts[attr] = ContactStore.parseContactsInString(query[attr])

    if query.body
      query.body = query.body.replace(/[\n\r]/g, '<br/>')

    Promise.props(contacts).then (contacts) =>
      @createDraft(Object.assign(query, contacts))

  createOrUpdateDraftForReply: ({message, thread, type, behavior}) =>
    unless type in ['reply', 'reply-all']
      throw new Error("createOrUpdateDraftForReply called with #{type}, not reply or reply-all")

    @candidateDraftForUpdating(message, behavior).then (existingDraft) =>
      if existingDraft
        @updateDraftForReply(existingDraft, {message, thread, type})
      else
        @createDraftForReply({message, thread, type})

  createDraftForReply: ({message, thread, type}) =>
    if type is 'reply'
      {to, cc} = message.participantsForReply()
    else if type is 'reply-all'
      {to, cc} = message.participantsForReplyAll()

    @createDraft(
      subject: subjectWithPrefix(message.subject, 'Re:')
      to: to,
      cc: cc,
      from: [@_fromContactForReply(message)],
      threadId: thread.id,
      accountId: message.accountId,
      replyToHeaderMessageId: message.headerMessageId,
      body: "" # quoted html is managed by the composer via the replyToHeaderMessageId
    )

  createDraftForForward: ({thread, message}) =>
    # Start downloading the attachments, if they haven't been already
    message.files.forEach((f) => Actions.fetchFile(f))

    contactsAsHtml = (cs) ->
      DOMUtils.escapeHTMLCharacters(_.invoke(cs, "toString").join(", "))
    fields = []
    fields.push("From: #{contactsAsHtml(message.from)}") if message.from.length > 0
    fields.push("Subject: #{message.subject}")
    fields.push("Date: #{message.formattedDate()}")
    fields.push("To: #{contactsAsHtml(message.to)}") if message.to.length > 0
    fields.push("Cc: #{contactsAsHtml(message.cc)}") if message.cc.length > 0

    DraftHelpers.prepareBodyForQuoting(message.body).then (body) =>
      @createDraft(
        subject: subjectWithPrefix(message.subject, 'Fwd:')
        from: [@_fromContactForReply(message)],
        files: message.files,
        threadId: thread.id,
        accountId: message.accountId,
        forwardedHeaderMessageId: message.headerMessageId,
        body: """
          <br><br>
          <div class="gmail_quote">
            <br>
            ---------- Forwarded message ---------
            <br><br>
            #{fields.join('<br>')}
            <br><br>
            #{body}
          </div>"""
      )

  createDraftForResurfacing: (thread, threadMessageId, body) =>
    account = AccountStore.accountForId(thread.accountId)
    if threadMessageId
      rthmsid = Promise.resolve(threadMessageId)
    else
      rthmsid = DatabaseStore
        .findBy(Message, {accountId: thread.accountId, threadId: thread.id})
        .order(Message.attributes.date.descending())
        .limit(1)
        .then((msg) =>
          return (msg && msg.headerMessageId || "")
        )

    return rthmsid.then((replyToHeaderMessageId) =>
      @createDraft({
        from: [new Contact({ email: account.emailAddress, name: "#{account.name} via Mailspring" })],
        to: [account.defaultMe()],
        cc: [],
        pristine: false,
        subject: thread.subject,
        threadId: thread.id,
        accountId: thread.accountId,
        replyToHeaderMessageId: replyToHeaderMessageId,
        body: body
      })
    )

  candidateDraftForUpdating: (message, behavior) =>
    if behavior not in ['prefer-existing-if-pristine', 'prefer-existing']
      return Promise.resolve(null)

    getMessages = DatabaseStore.findAll(Message, {threadId: message.threadId})
    if message.threadId is MessageStore.threadId()
      getMessages = Promise.resolve(MessageStore.items())

    getMessages.then (messages) =>
      candidateDrafts = messages.filter (other) =>
        other.replyToHeaderMessageId is message.headerMessageId and other.draft is true

      if candidateDrafts.length is 0
        return Promise.resolve(null)

      if behavior is 'prefer-existing'
        return Promise.resolve(candidateDrafts.pop())

      else if behavior is 'prefer-existing-if-pristine'
        DraftStore ?= require('./draft-store').default
        return Promise.all(candidateDrafts.map (candidateDraft) =>
          DraftStore.sessionForId(candidateDraft.id)
        ).then (sessions) =>
          for session in sessions
            if session.draft().pristine
              return Promise.resolve(session.draft())
          return Promise.resolve(null)


  updateDraftForReply: (draft, {type, message}) =>
    unless message and draft
      return Promise.reject("updateDraftForReply: Expected message and existing draft.")

    updated = {to: [].concat(draft.to), cc: [].concat(draft.cc)}
    replySet = message.participantsForReply()
    replyAllSet = message.participantsForReplyAll()

    if type is 'reply'
      targetSet = replySet

      # Remove participants present in the reply-all set and not the reply set
      for key in ['to', 'cc']
        updated[key] = _.reject updated[key], (contact) ->
          inReplySet = _.findWhere(replySet[key], {email: contact.email})
          inReplyAllSet = _.findWhere(replyAllSet[key], {email: contact.email})
          return inReplyAllSet and not inReplySet
    else
      # Add participants present in the reply-all set and not on the draft
      # Switching to reply-all shouldn't really ever remove anyone.
      targetSet = replyAllSet

    for key in ['to', 'cc']
      for contact in targetSet[key]
        updated[key].push(contact) unless _.findWhere(updated[key], {email: contact.email})

    draft.to = updated.to
    draft.cc = updated.cc
    return draft

  _fromContactForReply: (message) =>
    account = AccountStore.accountForId(message.accountId)
    defaultMe = account.defaultMe()
    result = defaultMe

    for aliasString in account.aliases
      alias = account.meUsingAlias(aliasString)
      for recipient in [].concat(message.to, message.cc)
        emailIsNotDefault = alias.email isnt defaultMe.email
        emailsMatch = recipient.email is alias.email
        nameIsNotDefault = alias.name isnt defaultMe.name
        namesMatch = recipient.name is alias.name

        # No better match is possible
        if emailsMatch and emailIsNotDefault and namesMatch and nameIsNotDefault
          return alias

        # A better match is possible. eg: the user may have two aliases with the same
        # email but different phrases, and we'll get an exact match on the other one.
        # Continue iterating and wait to see.
        if (emailsMatch and emailIsNotDefault) or (namesMatch and nameIsNotDefault)
          result = alias

    return result

  _accountForNewDraft: =>
    defAccountId = AppEnv.config.get('core.sending.defaultAccountIdForSend')
    account = AccountStore.accountForId(defAccountId)
    if account
      account
    else
      focusedAccountId = FocusedPerspectiveStore.current().accountIds[0]
      if focusedAccountId
        AccountStore.accountForId(focusedAccountId)
      else
        AccountStore.accounts()[0]

module.exports = new DraftFactory()
