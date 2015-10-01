_ = require 'underscore'
React = require 'react'
{Actions,
 DOMUtils,
 RemoveThreadHelper,
 FocusedMailViewStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class ThreadRemoveButton extends React.Component
  @displayName: "ThreadRemoveButton"
  @containerRequired: false

  render: =>
    focusedMailViewFilter = FocusedMailViewStore.mailView()
    return false unless focusedMailViewFilter?.canRemoveThreads()

    if RemoveThreadHelper.removeType() is RemoveThreadHelper.Type.Archive
      tooltip = "Archive"
      imgName = "toolbar-archive.png"
    else if RemoveThreadHelper.removeType() is RemoveThreadHelper.Type.Trash
      tooltip = "Trash"
      imgName = "toolbar-trash.png"

    <button className="btn btn-toolbar"
            style={order: -106}
            data-tooltip={tooltip}
            onClick={@_onRemove}>
      <RetinaImg name={imgName} mode={RetinaImg.Mode.ContentIsMask}/>
    </button>

  _onRemove: (e) =>
    return unless DOMUtils.nodeIsVisible(e.currentTarget)
    Actions.removeCurrentlyFocusedThread()
    e.stopPropagation()


module.exports = ThreadRemoveButton
