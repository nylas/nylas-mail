import React, {PropTypes} from 'react'
import ReactCSSTransitionGroup from 'react-addons-css-transition-group'
import {Rx, FocusedContentStore} from 'nylas-exports'
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

const MessageListToolbar = ({items, injectedButtons}) => {
  const shouldRender = items.length > 0

  return (
    <ReactCSSTransitionGroup
      className="message-toolbar-items"
      transitionLeaveTimeout={125}
      transitionEnterTimeout={125}
      transitionName="opacity-125ms"
    >
      {shouldRender ? injectedButtons : undefined}
    </ReactCSSTransitionGroup>
  )
}
MessageListToolbar.displayName = 'MessageListToolbar';
MessageListToolbar.propTypes = {
  items: PropTypes.array,
  injectedButtons: PropTypes.element,
};

const toolbarProps = {
  getObservable,
  extraRoles: [`MessageList:${ToolbarRole}`],
}

export default InjectsToolbarButtons(MessageListToolbar, toolbarProps)
