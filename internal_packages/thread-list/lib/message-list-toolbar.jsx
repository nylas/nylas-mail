import Rx from 'rx-lite'
import React, {Component, PropTypes} from 'react'
import {FocusedContentStore} from 'nylas-exports'
import {TimeoutTransitionGroup} from 'nylas-component-kit'
import ThreadListStore from './thread-list-store'
import InjectsToolbarButtons, {ToolbarRole} from './injects-toolbar-buttons'


function getObservable() {
  return (
    Rx.Observable.merge(
      Rx.Observable.fromStore(FocusedContentStore),
      ThreadListStore.selectionObservable(),
    )
    .map((data) => {
      const storeChanged = data === FocusedContentStore
      const selectionChanged = data instanceof Array

      if (storeChanged) {
        const focusedThread = FocusedContentStore.focused('thread')
        if (focusedThread) {
          return [focusedThread]
        }
      } else if (selectionChanged) {
        return data
      }
      return []
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
      <TimeoutTransitionGroup
        className="message-toolbar-items"
        leaveTimeout={125}
        enterTimeout={125}
        transitionName="opacity-125ms">
        {shouldRender ? injectedButtons : undefined}
      </TimeoutTransitionGroup>
    )
  }
}

const toolbarProps = {
  getObservable,
  extraRoles: [`MessageList:${ToolbarRole}`],
}

export default InjectsToolbarButtons(MessageListToolbar, toolbarProps)
