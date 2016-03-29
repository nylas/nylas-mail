import Rx from 'rx-lite'
import React, {Component, PropTypes} from 'react'
import ReactCSSTransitionGroup from 'react-addons-css-transition-group'
import {FocusedContentStore} from 'nylas-exports'
import ThreadListStore from './thread-list-store'
import InjectsToolbarButtons, {ToolbarRole} from './injects-toolbar-buttons'


function getObservable() {
  return (
    Rx.Observable.combineLatest(
      Rx.Observable.fromStore(FocusedContentStore),
      ThreadListStore.selectionObservable(),
      (store, items) => ({focusedThread: store.focused('thread'), items})
    )
    .map(({focusedThread, items}) => {
      if (focusedThread) {
        return [focusedThread]
      }
      return items
    })
  )
}

class MessageListToolbar extends Component {
  static displayName = 'MessageListToolbar';

  static propTypes = {
    items: PropTypes.array,
    injectedButtons: PropTypes.element,
  };

  render() {
    const {items, injectedButtons} = this.props
    const shouldRender = items.length > 0

    return (
      <ReactCSSTransitionGroup
        className="message-toolbar-items"
        transitionLeaveTimeout={125}
        transitionEnterTimeout={125}
        transitionName="opacity-125ms">
        {shouldRender ? injectedButtons : undefined}
      </ReactCSSTransitionGroup>
    )
  }
}

const toolbarProps = {
  getObservable,
  extraRoles: [`MessageList:${ToolbarRole}`],
}

export default InjectsToolbarButtons(MessageListToolbar, toolbarProps)
