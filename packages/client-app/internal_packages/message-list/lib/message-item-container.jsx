import React from 'react';
import classNames from 'classnames';
import {
  Utils,
  DraftStore,
  ComponentRegistry,
} from 'nylas-exports';

import MessageItem from './message-item';

export default class MessageItemContainer extends React.Component {
  static displayName = 'MessageItemContainer';

  static propTypes = {
    thread: React.PropTypes.object.isRequired,
    message: React.PropTypes.object.isRequired,
    messages: React.PropTypes.array.isRequired,
    collapsed: React.PropTypes.bool,
    isLastMsg: React.PropTypes.bool,
    isBeforeReplyArea: React.PropTypes.bool,
    scrollTo: React.PropTypes.func,
  };

  constructor(props, context) {
    super(props, context);
    this.state = this._getStateFromStores();
  }

  componentDidMount() {
    if (this.props.message.draft) {
      this._unlisten = DraftStore.listen(this._onSendingStateChanged);
    }
  }

  componentWillReceiveProps(newProps) {
    this.setState(this._getStateFromStores(newProps));
  }

  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.isEqualReact(nextProps, this.props) || !Utils.isEqualReact(nextState, this.state);
  }

  componentWillUnmount() {
    if (this._unlisten) {
      this._unlisten();
    }
  }

  focus = () => {
    this._messageComponent.focus();
  }

  _classNames() {
    return classNames({
      "draft": this.props.message.draft,
      "unread": this.props.message.unread,
      "collapsed": this.props.collapsed,
      "message-item-wrap": true,
      "before-reply-area": this.props.isBeforeReplyArea,
    });
  }

  _onSendingStateChanged = (headerMessageId) => {
    if (headerMessageId === this.props.message.headerMessageId) {
      this.setState(this._getStateFromStores());
    }
  }

  _getStateFromStores(props = this.props) {
    return {
      isSending: DraftStore.isSendingDraft(props.message.headerMessageId),
    };
  }

  _renderMessage({pending}) {
    return (
      <MessageItem
        ref={(cm) => { this._messageComponent = cm }}
        pending={pending}
        thread={this.props.thread}
        message={this.props.message}
        messages={this.props.messages}
        className={this._classNames()}
        collapsed={this.props.collapsed}
        isLastMsg={this.props.isLastMsg}
      />
    );
  }

  _renderComposer() {
    const Composer = ComponentRegistry.findComponentsMatching({role: 'Composer'})[0];
    if (!Composer) {
      return (<span>No Composer Component Present</span>);
    }
    return (
      <Composer
        ref={(cm) => { this._messageComponent = cm }}
        headerMessageId={this.props.message.headerMessageId}
        className={this._classNames()}
        mode={"inline"}
        threadId={this.props.thread.id}
        scrollTo={this.props.scrollTo}
      />
    );
  }

  render() {
    if (this.state.isSending) {
      return this._renderMessage({pending: true});
    }
    if (this.props.message.draft) {
      return this._renderComposer();
    }
    return this._renderMessage({pending: false});
  }
}
