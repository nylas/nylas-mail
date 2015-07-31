_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
MessageItem = require "./message-item"
{Utils,
 Actions,
 Message,
 DraftStore,
 MessageStore,
 DatabaseStore,
 WorkspaceStore,
 ComponentRegistry,
 ChangeLabelsTask,
 UpdateThreadsTask} = require("nylas-exports")

{Spinner,
 ScrollRegion,
 ResizableRegion,
 RetinaImg,
 InjectedComponentSet,
 MailLabel,
 InjectedComponent} = require('nylas-component-kit')

class HideSidebarButton extends React.Component
  constructor: (@props) ->
    @column = WorkspaceStore.Location.MessageListSidebar
    @state = @getStateFromStores()

  componentDidMount: =>
    @unlisten = WorkspaceStore.listen => @setState(@getStateFromStores())

  componentWillUnmount: =>
    @unlisten()

  render: =>
    if @state.hidden
      contents = {label: 'Show Sidebar', name: 'icon-thread-showsidebar.png'}
    else
      contents = {label: 'Hide Sidebar', name: 'icon-thread-hidesidebar.png'}

    <div className="hide-sidebar-button" style={@props.style} onClick={@_onClick}>
      <span className="img-wrap"><RetinaImg name={contents.name} mode={RetinaImg.Mode.ContentIsMask}/></span>
      {contents.label}
    </div>

  _onClick: =>
    Actions.toggleWorkspaceLocationHidden(@column)

  getStateFromStores: =>
    {hidden: WorkspaceStore.isLocationHidden(@column)}

class MessageListScrollTooltip extends React.Component
  @displayName: 'MessageListScrollTooltip'
  @propTypes:
    viewportCenter: React.PropTypes.number.isRequired
    totalHeight: React.PropTypes.number.isRequired

  componentWillMount: =>
    @setupForProps(@props)

  componentWillReceiveProps: (newProps) =>
    @setupForProps(newProps)

  shouldComponentUpdate: (newProps, newState) =>
    not _.isEqual(@state,newState)

  setupForProps: (props) ->
    # Technically, we could have MessageList provide the currently visible
    # item index, but the DOM approach is simple and self-contained.
    #
    els = document.querySelectorAll('.message-item-wrap')
    idx = _.findIndex els, (el) -> el.offsetTop > props.viewportCenter
    if idx is -1
      idx = els.length

    @setState
      idx: idx
      count: els.length

  render: ->
    <div className="scroll-tooltip">
      {@state.idx} of {@state.count}
    </div>

class MessageList extends React.Component
  @displayName: 'MessageList'
  @containerRequired: false
  @containerStyles:
    minWidth: 500
    maxWidth: 900

  constructor: (@props) ->
    @state = @_getStateFromStores()
    @state.minified = true
    @MINIFY_THRESHOLD = 3

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push MessageStore.listen @_onChange

    commands = _.extend {},
      'core:star-item': => @_onStar()
      'application:reply': => @_createReplyOrUpdateExistingDraft('reply')
      'application:reply-all': => @_createReplyOrUpdateExistingDraft('reply-all')
      'application:forward': => @_onForward()

    @command_unsubscriber = atom.commands.add('body', commands)

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers
    @command_unsubscriber.dispose()

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentDidUpdate: (prevProps, prevState) =>
    return if @state.loading

    newDraftIds = @_newDraftIds(prevState)
    if newDraftIds.length > 0
      @_focusDraft(@_getMessageElement(newDraftIds[0]))

  _newDraftIds: (prevState) =>
    oldDraftIds = _.map(_.filter((prevState.messages ? []), (m) -> m.draft), (m) -> m.id)
    newDraftIds = _.map(_.filter((@state.messages ? []), (m) -> m.draft), (m) -> m.id)
    return _.difference(newDraftIds, oldDraftIds) ? []

  _getMessageElement: (id) =>
    @refs["message-#{id}"]

  _focusDraft: (draftElement) =>
    draftElement.focus()
    @refs.messageWrap.scrollTo(draftElement, {
      position: ScrollRegion.ScrollPosition.Bottom,
      settle: true
    })

  _createReplyOrUpdateExistingDraft: (type) =>
    unless type in ['reply', 'reply-all']
      throw new Error("_createReplyOrUpdateExistingDraft called with #{type}, not reply or reply-all")
    return unless @state.currentThread

    last = _.last(@state.messages ? [])

    # If the last message on the thread is already a draft, fetch the message it's
    # in reply to and the draft session and change the participants.
    if last.draft is true
      data =
        session: DraftStore.sessionForLocalId(@state.messageLocalIds[last.id])
        replyToMessage: Promise.resolve(@state.messages[@state.messages.length - 2])

      if last.replyToMessageId
        msg = _.findWhere(@state.messages, {id: last.replyToMessageId})
        if msg
          data.replyToMessage = Promise.resolve(msg)
        else
          data.replyToMessage = DatabaseStore.find(Message, last.replyToMessageId)

      Promise.props(data).then ({session, replyToMessage}) =>
        return unless replyToMessage and session
        draft = session.draft()
        updated = {to: [].concat(draft.to), cc: [].concat(draft.cc)}

        replySet = replyToMessage.participantsForReply()
        replyAllSet = replyToMessage.participantsForReplyAll()

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

        session.changes.add(updated)
        @_focusDraft(@_getMessageElement(last.id))

    else
      if type is 'reply'
        Actions.composeReply(thread: @state.currentThread, message: last)
      else
        Actions.composeReplyAll(thread: @state.currentThread, message: last)

  _onStar: =>
    return unless @state.currentThread
    threads = [@state.currentThread]
    values = starred: (not @state.currentThread.starred)
    task = new UpdateThreadsTask(threads, values)
    Actions.queueTask(task)

  _onForward: =>
    return unless @state.currentThread
    Actions.composeForward(thread: @state.currentThread)

  render: =>
    if not @state.currentThread?
      return <div className="message-list" id="message-list"></div>

    wrapClass = classNames
      "messages-wrap": true
      "ready": not @state.loading

    <div className="message-list" id="message-list">
      <ScrollRegion tabIndex="-1"
           className={wrapClass}
           scrollTooltipComponent={MessageListScrollTooltip}
           ref="messageWrap">
        {@_renderSubject()}
        <div className="headers" style={position:'relative'}>
          <InjectedComponentSet
            className="message-list-notification-bars"
            matching={role:"MessageListNotificationBar"}
            exposedProps={thread: @state.currentThread}/>
          <InjectedComponentSet
            className="message-list-headers"
            matching={role:"MessageListHeaders"}
            exposedProps={thread: @state.currentThread}/>
        </div>
        {@_messageComponents()}
      </ScrollRegion>
      <Spinner visible={@state.loading} />
    </div>

  _renderSubject: ->
    <div className="message-subject-wrap">
      <HideSidebarButton style={float:'right'}/>
      <span className="message-subject">{@state.currentThread?.subject}</span>
      {@_renderLabels()}
    </div>

  _renderLabels: =>
    labels = @state.currentThread.sortedLabels() ? []
    labels.map (label) =>
      <MailLabel label={label} key={label.id} onRemove={ => @_onRemoveLabel(label) }/>

  _renderReplyArea: =>
    if @_hasReplyArea()
      <div className="footer-reply-area-wrap" onClick={@_onClickReplyArea} key={Utils.generateTempId()}>
        <div className="footer-reply-area">
          <RetinaImg name="#{@_replyType()}-footer.png" mode={RetinaImg.Mode.ContentIsMask}/>
          <span className="reply-text">Write a reply…</span>
        </div>
      </div>
    else
      <div key={Utils.generateTempId()}></div>

  _hasReplyArea: =>
    not _.last(@state.messages)?.draft

  # Either returns "reply" or "reply-all"
  _replyType: =>
    lastMsg = _.last(_.filter((@state.messages ? []), (m) -> not m.draft))
    if lastMsg?.cc.length is 0 and lastMsg?.to.length is 1
      return "reply"
    else
      return "reply-all"

  _onRemoveLabel: (label) =>
    task = new ChangeLabelsTask(threadIds: [@state.currentThread.id], labelsToRemove: [label])
    Actions.queueTask(task)

  _onClickReplyArea: =>
    return unless @state.currentThread
    @_createReplyOrUpdateExistingDraft(@_replyType())

  _messageComponents: =>
    components = []

    messages = @_messagesWithMinification(@state.messages)
    messages.forEach (message, idx) =>

      if message.type is "minifiedBundle"
        components.push(@_renderMinifiedBundle(message))
        return

      collapsed = !@state.messagesExpandedState[message.id]

      className = classNames
        "message-item-wrap": true
        "before-reply-area": (messages.length - 1 is idx) and @_hasReplyArea()
        "unread": message.unread
        "draft": message.draft
        "collapsed": collapsed

      if message.draft
        components.push <InjectedComponent matching={role:"Composer"}
                         exposedProps={ mode:"inline", localId:@state.messageLocalIds[message.id], onRequestScrollTo:@_onChildScrollRequest, threadId:@state.currentThread.id }
                         ref={"message-#{message.id}"}
                         key={@state.messageLocalIds[message.id]}
                         className={className} />
      else
        components.push <MessageItem key={message.id}
                         thread={@state.currentThread}
                         ref={"message-#{message.id}"}
                         message={message}
                         className={className}
                         collapsed={collapsed}
                         isLastMsg={(messages.length - 1 is idx)} />

    components.push @_renderReplyArea()

    return components

  _renderMinifiedBundle: (bundle) ->
    BUNDLE_HEIGHT = 36
    lines = bundle.messages[0...10]
    h = Math.round(BUNDLE_HEIGHT / lines.length)

    <div className="minified-bundle"
         onClick={ => @setState minified: false }
         key={Utils.generateTempId()}>
      <div className="num-messages">{bundle.messages.length} older messages</div>
      <div className="msg-lines" style={height: h*lines.length}>
        {lines.map (msg, i) ->
          <div style={height: h*2, top: -h*i} className="msg-line"></div>}
      </div>
    </div>

  _messagesWithMinification: (messages=[]) =>
    return messages unless @state.minified

    messages = _.clone(messages)
    minifyRanges = []
    consecutiveCollapsed = 0

    messages.forEach (message, idx) =>
      return if idx is 0 # Never minify the 1st message

      expandState = @state.messagesExpandedState[message.id]

      if not expandState
        consecutiveCollapsed += 1
      else
        # We add a +1 because we don't minify the last collapsed message,
        # but the MINIFY_THRESHOLD refers to the smallest N that can be in
        # the "N older messages" minified block.
        if expandState is "default"
          minifyOffset = 1
        else # if expandState is "explicit"
          minifyOffset = 0

        if consecutiveCollapsed >= @MINIFY_THRESHOLD + minifyOffset
          minifyRanges.push
            start: idx - consecutiveCollapsed
            length: (consecutiveCollapsed - minifyOffset)
        consecutiveCollapsed = 0

    indexOffset = 0
    for range in minifyRanges
      start = range.start - indexOffset
      minified =
        type: "minifiedBundle"
        messages: messages[start...(start+range.length)]
      messages.splice(start, range.length, minified)

      # While we removed `range.length` items, we also added 1 back in.
      indexOffset += (range.length - 1)

    return messages

  # Some child components (like the composer) might request that we scroll
  # to a given location. If `selectionTop` is defined that means we should
  # scroll to that absolute position.
  #
  # If messageId and location are defined, that means we want to scroll
  # smoothly to the top of a particular message.
  _onChildScrollRequest: ({messageId, rect}={}) =>
    if messageId
      @refs.messageWrap.scrollTo(@_getMessageElement(messageId), {
        position: ScrollRegion.ScrollPosition.Visible
      })
    else if rect
      @refs.messageWrap.scrollToRect(rect, {
        position: ScrollRegion.ScrollPosition.CenterIfInvisible
      })
    else
      throw new Error("onChildScrollRequest: expected messageId or rect")

  _onChange: =>
    newState = @_getStateFromStores()
    if @state.currentThread isnt newState.currentThread
      newState.minified = true
    @setState(newState)

  _getStateFromStores: =>
    messages: (MessageStore.items() ? [])
    messageLocalIds: MessageStore.itemLocalIds()
    messagesExpandedState: MessageStore.itemsExpandedState()
    currentThread: MessageStore.thread()
    loading: MessageStore.itemsLoading()

module.exports = MessageList
