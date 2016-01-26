React = require "react/addons"
classNames = require 'classnames'
{RetinaImg} = require 'nylas-component-kit'
{Actions, FocusedContentStore, DestroyDraftTask} = require "nylas-exports"

class DraftDeleteButton extends React.Component
  @displayName: 'DraftDeleteButton'
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  render: ->
    <button style={order:-100}
            className="btn btn-toolbar"
            title="Delete"
            onClick={@_destroySelected}>
      <RetinaImg name="icon-composer-trash.png" mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _destroySelected: =>
    for item in @props.selection.items()
      Actions.queueTask(new DestroyDraftTask(draftClientId: item.clientId))
    @props.selection.clear()
    return

module.exports = {DraftDeleteButton}
