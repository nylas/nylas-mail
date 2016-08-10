import _ from 'underscore'
import moment from 'moment'

import File from './file'
import Utils from './utils'
import Event from './event'
import Contact from './contact'
import Category from './category'
import Attributes from '../attributes'
import ModelWithMetadata from './model-with-metadata'
import QuotedHTMLTransformer from '../../services/quoted-html-transformer'


/**
Public: The Message model represents a Message object served by the Nylas Platform API.
For more information about Messages on the Nylas Platform, read the
[Messages API Documentation](https://nylas.com/cloud/docs#messages)

Messages are a sub-object of threads. The content of a message === immutable (with the
exception being drafts). Nylas does not support operations such as move || delete on
individual messages; those operations should be performed on the message’s thread.
All messages are part of a thread, even if that thread has only one message.

## Attributes

`to`: {AttributeCollection} A collection of {Contact} objects

`cc`: {AttributeCollection} A collection of {Contact} objects

`bcc`: {AttributeCollection} A collection of {Contact} objects

`from`: {AttributeCollection} A collection of {Contact} objects.

`replyTo`: {AttributeCollection} A collection of {Contact} objects.

`date`: {AttributeDateTime} When the message was delivered. Queryable.

`subject`: {AttributeString} The subject of the thread. Queryable.

`snippet`: {AttributeString} A short, 140-character plain-text summary of the message body.

`unread`: {AttributeBoolean} True if the message === unread. Queryable.

`starred`: {AttributeBoolean} True if the message === starred. Queryable.

`draft`: {AttributeBoolean} True if the message === a draft. Queryable.

`version`: {AttributeNumber} The version number of the message. Message
   versions are used for drafts, && increment when attributes are changed.

`files`: {AttributeCollection} A set of {File} models representing
   the attachments on this thread.

`body`: {AttributeJoinedData} The HTML body of the message. You must specifically
 request this attribute when querying for a Message using the {{AttributeJoinedData::include}}
 method.

`pristine`: {AttributeBoolean} True if the message === a draft which has not been
 edited since it was created.

`threadId`: {AttributeString} The ID of the Message's parent {Thread}. Queryable.

`replyToMessageId`: {AttributeString} The ID of a {Message} that this message
 === in reply to.

This class also inherits attributes from {Model}

Section: Models
*/
export default class Message extends ModelWithMetadata {

  static attributes = Object.assign({}, ModelWithMetadata.attributes, {
    to: Attributes.Collection({
      modelKey: 'to',
      itemClass: Contact,
    }),

    cc: Attributes.Collection({
      modelKey: 'cc',
      itemClass: Contact,
    }),

    bcc: Attributes.Collection({
      modelKey: 'bcc',
      itemClass: Contact,
    }),

    from: Attributes.Collection({
      modelKey: 'from',
      itemClass: Contact,
    }),

    replyTo: Attributes.Collection({
      modelKey: 'replyTo',
      jsonKey: 'reply_to',
      itemClass: Contact,
    }),

    date: Attributes.DateTime({
      queryable: true,
      modelKey: 'date',
    }),

    body: Attributes.JoinedData({
      modelTable: 'MessageBody',
      modelKey: 'body',
    }),

    files: Attributes.Collection({
      modelKey: 'files',
      itemClass: File,
    }),

    uploads: Attributes.Object({
      queryable: false,
      modelKey: 'uploads',
    }),

    unread: Attributes.Boolean({
      queryable: true,
      modelKey: 'unread',
    }),

    events: Attributes.Collection({
      modelKey: 'events',
      itemClass: Event,
    }),

    starred: Attributes.Boolean({
      queryable: true,
      modelKey: 'starred',
    }),

    snippet: Attributes.String({
      modelKey: 'snippet',
    }),

    threadId: Attributes.ServerId({
      queryable: true,
      modelKey: 'threadId',
      jsonKey: 'thread_id',
    }),

    subject: Attributes.String({
      modelKey: 'subject',
    }),

    draft: Attributes.Boolean({
      modelKey: 'draft',
      jsonKey: 'draft',
      queryable: true,
    }),

    pristine: Attributes.Boolean({
      modelKey: 'pristine',
      jsonKey: 'pristine',
      queryable: false,
    }),

    version: Attributes.Number({
      modelKey: 'version',
      queryable: true,
    }),

    replyToMessageId: Attributes.ServerId({
      modelKey: 'replyToMessageId',
      jsonKey: 'reply_to_message_id',
    }),

    categories: Attributes.Collection({
      modelKey: 'categories',
      itemClass: Category,
    }),
  });

  static naturalSortOrder() {
    return Message.attributes.date.ascending()
  }

  static additionalSQLiteConfig = {
    setup: () => [
      `CREATE INDEX IF NOT EXISTS MessageListThreadIndex ON Message(thread_id, date ASC)`,
      `CREATE UNIQUE INDEX IF NOT EXISTS MessageDraftIndex ON Message(client_id)`,
      `CREATE INDEX IF NOT EXISTS MessageListDraftIndex ON \
Message(account_id, date DESC) WHERE draft = 1`,
      `CREATE INDEX IF NOT EXISTS MessageListUnifiedDraftIndex ON \
Message(date DESC) WHERE draft = 1`,
      `CREATE UNIQUE INDEX IF NOT EXISTS MessageBodyIndex ON MessageBody(id)`,
    ],
  }

  constructor(args) {
    super(args);
    this.subject = this.subject || ""
    this.to = this.to || []
    this.cc = this.cc || []
    this.bcc = this.bcc || []
    this.from = this.from || []
    this.replyTo = this.replyTo || []
    this.files = this.files || []
    this.uploads = this.uploads || []
    this.events = this.events || []
    this.categories = this.categories || []
  }

  toJSON(options) {
    const json = super.toJSON(options)
    json.file_ids = this.fileIds()
    if (this.draft) {
      json.object = 'draft'
    }

    if (this.events && this.events.length) {
      json.event_id = this.events[0].serverId
    }

    return json
  }

  fromJSON(json = {}) {
    super.fromJSON(json)

    // Only change the `draft` bit if the incoming json has an `object`
    // property. Because of `DraftChangeSet`, it's common for incoming json
    // to be an empty hash. In this case we want to leave the pre-existing
    // draft bit alone.
    if (json.object) {
      this.draft = (json.object === 'draft')
    }

    if (json.folder) {
      this.categories = this.constructor.attributes.categories.fromJSON([json.folder])
    } else if (json.labels) {
      this.categories = this.constructor.attributes.categories.fromJSON(json.labels)
    }

    for (const attr of ['to', 'from', 'cc', 'bcc', 'files', 'categories']) {
      const values = this[attr]
      if (!(values && values instanceof Array)) {
        continue;
      }
      for (const item of values) {
        item.accountId = this.accountId
      }
    }

    return this
  }

  canReplyAll() {
    const {to, cc} = this.participantsForReplyAll()
    return to.length > 1 || cc.length > 0
  }

  // Public: Returns a set of uniqued message participants by combining the
  // `to`, `cc`, `bcc` && (optionally) `from` fields.
  participants({includeFrom = true, includeBcc = false} = {}) {
    const seen = {}
    const all = []
    let contacts = [].concat(this.to, this.cc)
    if (includeFrom) {
      contacts = _.union(contacts, (this.from || []))
    }
    if (includeBcc) {
      contacts = _.union(contacts, (this.bcc || []))
    }
    for (const contact of contacts) {
      if (!contact.email) {
        continue
      }
      const key = contact.toString().trim().toLowerCase()
      if (seen[key]) {
        continue;
      }
      seen[key] = true
      all.push(contact)
    }
    return all
  }

  // Public: Returns a hash with `to` && `cc` keys for authoring a new draft in
  // "reply all" to this message. This method takes into account whether the
  // message === from the current user, && also looks at the replyTo field.
  participantsForReplyAll() {
    const excludedFroms = this.from.map((c) =>
      Utils.toEquivalentEmailForm(c.email)
    );

    const excludeMeAndFroms = (cc) =>
      _.reject(cc, (p) =>
        p.isMe() || _.contains(excludedFroms, Utils.toEquivalentEmailForm(p.email))
      );

    let to = null
    let cc = null

    if (this.replyTo.length) {
      to = this.replyTo
      cc = excludeMeAndFroms([].concat(this.to, this.cc))
    } else if (this.isFromMe()) {
      to = this.to
      cc = excludeMeAndFroms(this.cc)
    } else {
      to = this.from
      cc = excludeMeAndFroms([].concat(this.to, this.cc))
    }

    to = _.uniq(to, (p) => Utils.toEquivalentEmailForm(p.email))
    cc = _.uniq(cc, (p) => Utils.toEquivalentEmailForm(p.email))
    return {to, cc}
  }

  // Public: Returns a hash with `to` && `cc` keys for authoring a new draft in
  // "reply" to this message. This method takes into account whether the
  // message === from the current user, && also looks at the replyTo field.
  participantsForReply() {
    let to = []
    const cc = []

    if (this.replyTo.length) {
      to = this.replyTo;
    } else if (this.isFromMe()) {
      to = this.to
    } else {
      to = this.from
    }

    to = _.uniq(to, (p) => Utils.toEquivalentEmailForm(p.email))
    return {to, cc}
  }

  // Public: Returns an {Array} of {File} IDs
  fileIds() {
    return _.map(this.files, (file) => file.id)
  }

  // Public: Returns true if this message === from the current user's email
  // address. In the future, this method will take into account all of the
  // user's email addresses && accounts.
  isFromMe() {
    return this.from[0] ? this.from[0].isMe() : false
  }

  // Public: Returns a plaintext version of the message body using Chromium's
  // DOMParser. Use with care.
  computePlainText(options = {}) {
    if ((this.body || "").trim().length === 0) {
      return ""
    }
    if (options.includeQuotedText) {
      return (new DOMParser()).parseFromString(this.body, "text/html").body.innerText
    }
    const doc = QuotedHTMLTransformer.removeQuotedHTML(this.body, {returnAsDOM: true});
    return doc.body.innerText
  }

  fromContact() {
    return ((this.from || [])[0] || new Contact({name: 'Unknown', email: 'Unknown'}))
  }

  // Public: Returns the standard attribution line for this message,
  // localized for the current user.
  // ie "On Dec. 12th, 2015 at 4:00PM, Ben Gotow wrote:"
  replyAttributionLine() {
    return `On ${this.formattedDate()}, ${this.fromContact().toString()} wrote:`
  }

  formattedDate() {
    return moment(this.date).format("MMM D YYYY, [at] h:mm a")
  }

  hasEmptyBody() {
    if (!this.body) { return true }

    // https://regex101.com/r/hR7zN3/1
    const re = /(?:<signature>.*<\/signature>)|(?:<.+?>)|\s/gmi;
    return this.body.replace(re, "").length === 0;
  }
}
