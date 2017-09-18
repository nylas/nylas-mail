import React from 'react'
import ReactDOM from 'react-dom'
import classNames from 'classnames'

import {
  Utils,
  Actions,
  MessageStore,
  SearchableComponentStore,
  SearchableComponentMaker,
} from "nylas-exports"

import {
  Spinner,
  RetinaImg,
  MailLabelSet,
  ScrollRegion,
  MailImportantIcon,
  KeyCommandsRegion,
  InjectedComponentSet,
} from 'nylas-component-kit'

import FindInThread from './find-in-thread'
import MessageItemContainer from './message-item-container'

class MessageListScrollTooltip extends React.Component {
  static displayName = 'MessageListScrollTooltip';
  static propTypes = {
    viewportCenter: React.PropTypes.number.isRequired,
    totalHeight: React.PropTypes.number.isRequired,
  };

  componentWillMount() {
    this.setupForProps(this.props);
  }

  componentWillReceiveProps(newProps) {
    this.setupForProps(newProps);
  }

  shouldComponentUpdate(newProps, newState) {
    return !Utils.isEqualReact(this.state, newState);
  }

  setupForProps(props) {
    // Technically, we could have MessageList provide the currently visible
    // item index, but the DOM approach is simple and self-contained.
    //
    const els = document.querySelectorAll('.message-item-wrap')
    let idx = Array.from(els).findIndex((el) => el.offsetTop > props.viewportCenter);
    if (idx === -1) {
      idx = els.length;
    }

    this.setState({
      idx: idx,
      count: els.length,
    });
  }

  render() {
    return (
      <div className="scroll-tooltip">
        {this.state.idx} of {this.state.count}
      </div>
    );
  }
}

class MessageList extends React.Component {
  static displayName = 'MessageList';
  static containerRequired = false;
  static containerStyles = {
    minWidth: 500,
    maxWidth: 999999,
  };

  constructor(props) {
    super(props);
    this.state = this._getStateFromStores();
    this.state.minified = true;
    this._draftScrollInProgress = false;
    this.MINIFY_THRESHOLD = 3;
  }

  componentDidMount() {
    this._unsubscribers = [];
    this._unsubscribers.push(MessageStore.listen(this._onChange));
    this._unsubscribers.push(Actions.focusDraft.listen(async ({headerMessageId}) => {
      Utils.waitFor(() =>
        this._getMessageContainer(headerMessageId) !== undefined
      ).then(() =>
        this._focusDraft(this._getMessageContainer(headerMessageId))
      ).catch(() => {
        // may have been a popout composer
      })
    }));
  }

  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.isEqualReact(nextProps, this.props) || !Utils.isEqualReact(nextState, this.state);
  }

  componentDidUpdate() {
    // cannot remove
  }

  componentWillUnmount() {
    for (const unsubscribe of this._unsubscribers) {
      unsubscribe();
    }
  }

  _globalMenuItems() {
    const toggleExpandedLabel = this.state.hasCollapsedItems ? "Expand" : "Collapse";
    return [
      {
        label: "Thread",
        submenu: [{
          label: `${toggleExpandedLabel} conversation`,
          command: "message-list:toggle-expanded",
          position: "endof=view-actions",
        }],
      },
    ];
  }

  _globalKeymapHandlers() {
    const handlers = {
      'core:reply': () =>
        Actions.composeReply({
          thread: this.state.currentThread,
          message: this._lastMessage(),
          type: 'reply',
          behavior: 'prefer-existing',
        }),
      'core:reply-all': () =>
        Actions.composeReply({
          thread: this.state.currentThread,
          message: this._lastMessage(),
          type: 'reply-all',
          behavior: 'prefer-existing',
        }),
      'core:forward': () => this._onForward(),
      'core:print-thread': () => this._onPrintThread(),
      'core:messages-page-up': () => this._onScrollByPage(-1),
      'core:messages-page-down': () => this._onScrollByPage(1),
    };

    if (this.state.canCollapse) {
      handlers['message-list:toggle-expanded'] = () => this._onToggleAllMessagesExpanded();
    }

    return handlers;
  }

  _getMessageContainer(headerMessageId) {
    return this.refs[`message-container-${headerMessageId}`];
  }

  _focusDraft(draftElement) {
    // Note: We don't want the contenteditable view competing for scroll offset,
    // so we block incoming childScrollRequests while we scroll to the new draft.
    this._draftScrollInProgress = true;
    draftElement.focus();
    this._messageWrapEl.scrollTo(draftElement, {
      position: ScrollRegion.ScrollPosition.Top,
      settle: true,
      done: () => {
        this._draftScrollInProgress = false
      },
    });
  }

  _onForward = () => {
    if (!this.state.currentThread) {
      return;
    }
    Actions.composeForward({thread: this.state.currentThread})
  }

  _lastMessage() {
    return (this.state.messages || []).filter(m => !m.draft).pop();
  }

  // Returns either "reply" or "reply-all"
  _replyType() {
    const defaultReplyType = NylasEnv.config.get('core.sending.defaultReplyType');
    const lastMessage = this._lastMessage();
    if (!lastMessage) {
      return 'reply';
    }

    if (lastMessage.canReplyAll()) {
      return defaultReplyType === 'reply-all' ? 'reply-all' : 'reply';
    }
    return 'reply';
  }

  _onToggleAllMessagesExpanded = () => {
    Actions.toggleAllMessagesExpanded();
  }

  _onPrintThread = () => {
    const node = ReactDOM.findDOMNode(this)
    Actions.printThread(this.state.currentThread, node.innerHTML)
  }

  _onPopThreadIn = () => {
    if (!this.state.currentThread) {
      return;
    }
    Actions.focusThreadMainWindow(this.state.currentThread)
    NylasEnv.close()
  }

  _onPopoutThread = () => {
    if (!this.state.currentThread) {
      return;
    }
    Actions.popoutThread(this.state.currentThread);
    // This returns the single-pane view to the inbox, and does nothing for
    // double-pane view because we're at the root sheet.
    Actions.popSheet();
  }

  _onClickReplyArea = () => {
    if (!this.state.currentThread) {
      return;
    }
    Actions.composeReply({
      thread: this.state.currentThread,
      message: this._lastMessage(),
      type: this._replyType(),
      behavior: 'prefer-existing-if-pristine',
    });
  }

  _messageElements() {
    const {messagesExpandedState, currentThread} = this.state;
    const elements = [];
    let lastMessageIdx;

    const descendingOrderMessageList = NylasEnv.config.get('core.reading.descendingOrderMessageList');
    let messages = this._messagesWithMinification(this.state.messages);

    // Check on whether to display items in descending order
    if (descendingOrderMessageList) {
      messages = messages.reverse();
      lastMessageIdx = 0;
    } else {
      lastMessageIdx = messages.length - 1;
    }

    const lastItem = this.state.messages[descendingOrderMessageList ? 0 : this.state.messages.length - 1];
    const hasReplyArea = lastItem && !lastItem.draft;

    messages.forEach((message, idx) => {
      if (message.type === "minifiedBundle") {
        elements.push(this._renderMinifiedBundle(message))
        return;
      }

      const collapsed = !messagesExpandedState[message.id];
      const isLastItem = (lastMessageIdx === idx);
      const isBeforeReplyArea = isLastItem && hasReplyArea;

      elements.push(
        <MessageItemContainer
          key={message.id}
          ref={`message-container-${message.headerMessageId}`}
          thread={currentThread}
          message={message}
          messages={messages}
          collapsed={collapsed}
          isLastItem={isLastItem}
          isBeforeReplyArea={isBeforeReplyArea}
          scrollTo={this._scrollTo}
        />
      );
    });
    if (hasReplyArea && lastItem) {
      elements.push(this._renderReplyArea());
    }
    return elements;
  }

  _messagesWithMinification(allMessages = []) {
    if (!this.state.minified) {
      return allMessages;
    }

    const messages = [].concat(allMessages);
    const minifyRanges = []
    let consecutiveCollapsed = 0

    messages.forEach((message, idx) => {
      // Never minify the 1st message
      if (idx === 0) {
        return;
      }

      const expandState = this.state.messagesExpandedState[message.id];

      if (!expandState) {
        consecutiveCollapsed += 1
      } else {
        // We add a +1 because we don't minify the last collapsed message,
        // but the MINIFY_THRESHOLD refers to the smallest N that can be in
        // the "N older messages" minified block.
        const minifyOffset = (expandState === "default") ? 1 : 0;

        if (consecutiveCollapsed >= this.MINIFY_THRESHOLD + minifyOffset) {
          minifyRanges.push({
            start: idx - consecutiveCollapsed,
            length: (consecutiveCollapsed - minifyOffset),
          });
        }
        consecutiveCollapsed = 0;
      }
    });

    let indexOffset = 0;
    for (const range of minifyRanges) {
      const start = range.start - indexOffset
      const minified = {
        type: "minifiedBundle",
        messages: messages.slice(start, start + range.length),
      }
      messages.splice(start, range.length, minified);

      // While we removed `range.length` items, we also added 1 back in.
      indexOffset += (range.length - 1);
    }
    return messages;
  }

  // Some child components (like the composer) might request that we scroll
  // to a given location. If `selectionTop` is defined that means we should
  // scroll to that absolute position.
  //
  // If messageId and location are defined, that means we want to scroll
  // smoothly to the top of a particular message.
  _scrollTo = ({id, rect, position} = {}) => {
    if (this._draftScrollInProgress) {
      return;
    }
    if (id) {
      const messageElement = this._getMessageContainer(id);
      if (!messageElement) {
        return;
      }
      this._messageWrapEl.scrollTo(messageElement, {
        position: position !== undefined ? position : ScrollRegion.ScrollPosition.Visible,
      });
    } else if (rect) {
      this._messageWrapEl.scrollToRect(rect, {
        position: ScrollRegion.ScrollPosition.CenterIfInvisible,
      });
    } else {
      throw new Error("onChildScrollRequest: expected id or rect")
    }
  }

  _onScrollByPage = (direction) => {
    const height = ReactDOM.findDOMNode(this._messageWrapEl).clientHeight;
    this._messageWrapEl.scrollTop += height * direction;
  }

  _onChange = () => {
    const newState = this._getStateFromStores()
    if ((this.state.currentThread || {}).id !== (newState.currentThread || {}).id) {
      newState.minified = true;
    }
    this.setState(newState);
  }

  _getStateFromStores() {
    return {
      messages: (MessageStore.items() || []),
      messagesExpandedState: MessageStore.itemsExpandedState(),
      canCollapse: MessageStore.items().length > 1,
      hasCollapsedItems: MessageStore.hasCollapsedItems(),
      currentThread: MessageStore.thread(),
      loading: MessageStore.itemsLoading(),
    };
  }

  _renderSubject() {
    let subject = this.state.currentThread.subject
    if (!subject || subject.length === 0) {
      subject = "(No Subject)";
    }

    return (
      <div className="message-subject-wrap">
        <MailImportantIcon thread={this.state.currentThread} />
        <div style={{flex: 1}}>
          <span className="message-subject">{subject}</span>
          <MailLabelSet
            removable
            includeCurrentCategories
            messages={this.state.messages}
            thread={this.state.currentThread}
          />
        </div>
        {this._renderIcons()}
      </div>
    );
  }

  _renderIcons() {
    return (
      <div className="message-icons-wrap">
        {this._renderExpandToggle()}
        <div onClick={this._onPrintThread}>
          <RetinaImg name="print.png" title="Print Thread" mode={RetinaImg.Mode.ContentIsMask} />
        </div>
        {this._renderPopoutToggle()}
      </div>
    );
  }

  _renderExpandToggle() {
    if (!this.state.canCollapse) {
      return (<span />);
    }

    return (
      <div onClick={this._onToggleAllMessagesExpanded}>
        <RetinaImg
          name={this.state.hasCollapsedItems ? "expand.png" : "collapse.png"}
          title={this.state.hasCollapsedItems ? "Expand All" : "Collapse All"}
          mode={RetinaImg.Mode.ContentIsMask}
        />
      </div>
    );
  }

  _renderPopoutToggle() {
    if (NylasEnv.isThreadWindow()) {
      return (
        <div onClick={this._onPopThreadIn}>
          <RetinaImg name="thread-popin.png" title="Pop thread in" mode={RetinaImg.Mode.ContentIsMask} />
        </div>
      );
    }
    return (
      <div onClick={this._onPopoutThread}>
        <RetinaImg name="thread-popout.png" title="Popout thread" mode={RetinaImg.Mode.ContentIsMask} />
      </div>
    );
  }

  _renderReplyArea() {
    return (
      <div className="footer-reply-area-wrap" onClick={this._onClickReplyArea} key="reply-area">
        <div className="footer-reply-area">
          <RetinaImg name={`${this._replyType()}-footer.png`} mode={RetinaImg.Mode.ContentIsMask} />
          <span className="reply-text">Write a reply…</span>
        </div>
      </div>
    );
  }

  _renderMinifiedBundle(bundle) {
    const BUNDLE_HEIGHT = 36;
    const lines = bundle.messages.slice(0, 10);
    const h = Math.round(BUNDLE_HEIGHT / lines.length);

    return (
      <div
        className="minified-bundle"
        onClick={() => this.setState({minified: false})}
        key={Utils.generateTempId()}
      >
        <div className="num-messages">{bundle.messages.length} older messages</div>
        <div className="msg-lines" style={{height: h * lines.length}}>
          {lines.map((msg, i) =>
            <div key={msg.id} style={{height: h * 2, top: -h * i}} className="msg-line" />
          )}
        </div>
      </div>
    );
  }

  render() {
    if (!this.state.currentThread) {
      return (<span />);
    }

    const wrapClass = classNames({
      "messages-wrap": true,
      "ready": !this.state.loading,
    })

    const messageListClass = classNames({
      "message-list": true,
      "height-fix": SearchableComponentStore.searchTerm !== null,
    });

    return (
      <KeyCommandsRegion
        globalHandlers={this._globalKeymapHandlers()}
        globalMenuItems={this._globalMenuItems()}
      >
        <FindInThread />
        <div className={messageListClass} id="message-list">
          <ScrollRegion
            tabIndex="-1"
            className={wrapClass}
            scrollbarTickProvider={SearchableComponentStore}
            scrollTooltipComponent={MessageListScrollTooltip}
            ref={(el) => { this._messageWrapEl = el }}
          >
            {this._renderSubject()}
            <div className="headers" style={{position: 'relative'}}>
              <InjectedComponentSet
                className="message-list-headers"
                matching={{role: "MessageListHeaders"}}
                exposedProps={{thread: this.state.currentThread, messages: this.state.messages}}
                direction="column"
              />
            </div>
            {this._messageElements()}
          </ScrollRegion>
          <Spinner visible={this.state.loading} />
        </div>
      </KeyCommandsRegion>
    );
  }
}

export default SearchableComponentMaker.extend(MessageList);
