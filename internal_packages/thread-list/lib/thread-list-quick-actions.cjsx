React = require 'react'
{Actions,
 RemoveThreadHelper,
 FocusedMailViewStore} = require 'nylas-exports'

class ThreadListQuickActions extends React.Component
  @displayName: 'ThreadListQuickActions'
  @propTypes:
    thread: React.PropTypes.object

  render: =>
    focusedMailViewFilter = FocusedMailViewStore.mailView()
    return false unless focusedMailViewFilter?.canRemoveThreads()

    classNames = "btn action action-#{RemoveThreadHelper.removeType()}"

    <div className="inner">
      <div key="remove" className={classNames} onClick={@_onRemove}></div>
    </div>

  shouldComponentUpdate: (newProps, newState) ->
    newProps.thread.id isnt @props?.thread.id

  _onRemove: (event) =>
    focusedMailViewFilter = FocusedMailViewStore.mailView()
    t = RemoveThreadHelper.getRemovalTask([@props.thread], focusedMailViewFilter)
    Actions.queueTask(t)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = ThreadListQuickActions
