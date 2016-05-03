_ = require 'underscore'
React = require 'react'
ReactDOM = require 'react-dom'
classNames = require 'classnames'
FindInThread = require('./find-in-thread').default
MessageItemContainer = require './message-item-container'

{Utils,
 Actions,
 Message,
 DraftStore,
 MessageStore,
 AccountStore,
 DatabaseStore,
 WorkspaceStore,
 ChangeLabelsTask,
 ComponentRegistry,
 ChangeStarredTask,
 SearchableComponentStore
 SearchableComponentMaker} = require("nylas-exports")

{Spinner,
 RetinaImg,
 MailLabelSet,
 ScrollRegion,
 MailImportantIcon,
 InjectedComponent,
 KeyCommandsRegion,
 InjectedComponentSet} = require('nylas-component-kit')

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
    maxWidth: 999999

  constructor: (@props) ->
    @state = @_getStateFromStores()
    @state.minified = true
    @_draftScrollInProgress = false
    @MINIFY_THRESHOLD = 3

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push MessageStore.listen @_onChange
    @_unsubscribers.push Actions.focusDraft.listen ({draftClientId}) =>
      Utils.waitFor( => @_getMessageContainer(draftClientId)?).then =>
        @_focusDraft(@_getMessageContainer(draftClientId))
      .catch =>

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentDidUpdate: (prevProps, prevState) =>

  _globalMenuItems: ->
    toggleExpandedLabel = if @state.hasCollapsedItems then "Expand" else "Collapse"
    [
      {
        "label": "Thread",
        "submenu": [{
          "label": "#{toggleExpandedLabel} conversation",
          "command": "message-list:toggle-expanded",
          "position": "endof=view-actions",
        }]
      }
    ]

  _globalKeymapHandlers: ->
    handlers =
      'core:reply': =>
        Actions.composeReply({
          thread: @state.currentThread,
          message: @_lastMessage(),
          type: 'reply',
          behavior: 'prefer-existing',
        })
      'core:reply-all': =>
        Actions.composeReply({
          thread: @state.currentThread,
          message: @_lastMessage(),
          type: 'reply-all',
          behavior: 'prefer-existing',
        })
      'core:forward': => @_onForward()
      'core:print-thread': => @_onPrintThread()
      'core:messages-page-up': => @_onScrollByPage(-1)
      'core:messages-page-down': => @_onScrollByPage(1)

    if @state.canCollapse
      handlers['message-list:toggle-expanded'] = => @_onToggleAllMessagesExpanded()

    handlers

  _getMessageContainer: (clientId) =>
    @refs["message-container-#{clientId}"]

  _focusDraft: (draftElement) =>
    # Note: We don't want the contenteditable view competing for scroll offset,
    # so we block incoming childScrollRequests while we scroll to the new draft.
    @_draftScrollInProgress = true
    draftElement.focus()
    @refs.messageWrap.scrollTo(draftElement, {
      position: ScrollRegion.ScrollPosition.Top,
      settle: true,
      done: =>
        @_draftScrollInProgress = false
    })

  _onForward: =>
    return unless @state.currentThread
    Actions.composeForward(thread: @state.currentThread)

  render: =>
    if not @state.currentThread
      return <span />

    wrapClass = classNames
      "messages-wrap": true
      "ready": not @state.loading

    messageListClass = classNames
      "message-list": true
      "height-fix": SearchableComponentStore.searchTerm isnt null

    <KeyCommandsRegion
      globalHandlers={@_globalKeymapHandlers()}
      globalMenuItems={@_globalMenuItems()}>
      <FindInThread ref="findInThread" />
      <div className={messageListClass} id="message-list">
        <ScrollRegion tabIndex="-1"
             className={wrapClass}
             scrollbarTickProvider={SearchableComponentStore}
             scrollTooltipComponent={MessageListScrollTooltip}
             ref="messageWrap">
          {@_renderSubject()}
          <div className="headers" style={position:'relative'}>
            <InjectedComponentSet
              className="message-list-headers"
              matching={role:"MessageListHeaders"}
              exposedProps={thread: @state.currentThread}
              direction="column"/>
          </div>
          {@_messageElements()}
        </ScrollRegion>
        <Spinner visible={@state.loading} />
      </div>
    </KeyCommandsRegion>

  _renderSubject: ->
    subject = @state.currentThread.subject
    subject = "(No Subject)" if not subject or subject.length is 0

    <div className="message-subject-wrap">
      <MailImportantIcon thread={@state.currentThread}/>
      <div style={flex: 1}>
        <span className="message-subject">{subject}</span>
        <MailLabelSet removable={true} thread={@state.currentThread} includeCurrentCategories={true} />
      </div>
      {@_renderIcons()}
    </div>

  _renderIcons: =>
    <div className="message-icons-wrap">
      {@_renderExpandToggle()}
      <div onClick={@_onPrintThread}>
        <RetinaImg name="print.png" title="Print Thread" mode={RetinaImg.Mode.ContentIsMask}/>
      </div>
    </div>

  _renderExpandToggle: =>
    return <span/> unless @state.canCollapse

    if @state.hasCollapsedItems
      <div onClick={@_onToggleAllMessagesExpanded}>
        <RetinaImg name={"expand.png"} title={"Expand All"} mode={RetinaImg.Mode.ContentIsMask}/>
      </div>
    else
      <div onClick={@_onToggleAllMessagesExpanded}>
        <RetinaImg name={"collapse.png"} title={"Collapse All"} mode={RetinaImg.Mode.ContentIsMask}/>
      </div>

  _renderReplyArea: =>
    <div className="footer-reply-area-wrap" onClick={@_onClickReplyArea} key='reply-area'>
      <div className="footer-reply-area">
        <RetinaImg name="#{@_replyType()}-footer.png" mode={RetinaImg.Mode.ContentIsMask}/>
        <span className="reply-text">Write a reply…</span>
      </div>
    </div>

  _lastMessage: =>
    _.last(_.filter((@state.messages ? []), (m) -> not m.draft))

  # Returns either "reply" or "reply-all"
  _replyType: =>
    defaultReplyType = NylasEnv.config.get('core.sending.defaultReplyType')
    lastMessage = @_lastMessage()
    return 'reply' unless lastMessage

    if lastMessage.canReplyAll()
      if defaultReplyType is 'reply-all'
        return 'reply-all'
      else
        return 'reply'
    else
      return 'reply'

  _onToggleAllMessagesExpanded: ->
    Actions.toggleAllMessagesExpanded()

  _onPrintThread: =>
    node = ReactDOM.findDOMNode(@)
    Actions.printThread(@state.currentThread, node.innerHTML)

  _onClickReplyArea: =>
    return unless @state.currentThread
    Actions.composeReply({
      thread: @state.currentThread,
      message: @_lastMessage(),
      type: @_replyType(),
      behavior: 'prefer-existing-if-pristine',
    })

  _messageElements: =>
    elements = []

    hasReplyArea = not _.last(@state.messages)?.draft
    messages = @_messagesWithMinification(@state.messages)
    messages.forEach (message, idx) =>

      if message.type is "minifiedBundle"
        elements.push(@_renderMinifiedBundle(message))
        return

      collapsed = !@state.messagesExpandedState[message.id]
      isLastMsg = (messages.length - 1 is idx)
      isBeforeReplyArea = isLastMsg and hasReplyArea

      elements.push(
        <MessageItemContainer key={message.clientId}
                              ref={"message-container-#{message.clientId}"}
                              thread={@state.currentThread}
                              message={message}
                              collapsed={collapsed}
                              isLastMsg={isLastMsg}
                              isBeforeReplyArea={isBeforeReplyArea}
                              scrollTo={@_scrollTo} />
      )

    if hasReplyArea
      elements.push(@_renderReplyArea())

    return elements

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
          <div key={msg.id} style={height: h*2, top: -h*i} className="msg-line"></div>}
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
  _scrollTo: ({clientId, rect, position}={}) =>
    return if @_draftScrollInProgress
    if clientId
      messageElement = @_getMessageContainer(clientId)
      return unless messageElement
      pos = position ? ScrollRegion.ScrollPosition.Visible
      @refs.messageWrap.scrollTo(messageElement, {
        position: pos
      })
    else if rect
      @refs.messageWrap.scrollToRect(rect, {
        position: ScrollRegion.ScrollPosition.CenterIfInvisible
      })
    else
      throw new Error("onChildScrollRequest: expected clientId or rect")

  _onScrollByPage: (direction) =>
    height = ReactDOM.findDOMNode(@refs.messageWrap).clientHeight
    @refs.messageWrap.scrollTop += height * direction

  _onChange: =>
    newState = @_getStateFromStores()
    if @state.currentThread?.id isnt newState.currentThread?.id
      newState.minified = true
    @setState(newState)

  _getStateFromStores: =>
    messages: (MessageStore.items() ? [])
    messagesExpandedState: MessageStore.itemsExpandedState()
    canCollapse: MessageStore.items().length > 1
    hasCollapsedItems: MessageStore.hasCollapsedItems()
    currentThread: MessageStore.thread()
    loading: MessageStore.itemsLoading()

module.exports = SearchableComponentMaker.extend(MessageList)
