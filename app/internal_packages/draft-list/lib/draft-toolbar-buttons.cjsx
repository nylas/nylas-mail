{RetinaImg} = require 'nylas-component-kit'
{React, PropTypes, Actions, FocusedContentStore} = require "mailspring-exports"

class DraftDeleteButton extends React.Component
  @displayName: 'DraftDeleteButton'
  @containerRequired: false

  @propTypes:
    selection: PropTypes.object.isRequired

  render: ->
    <button style={order:-100}
            className="btn btn-toolbar"
            title="Delete"
            onClick={@_destroySelected}>
      <RetinaImg name="icon-composer-trash.png" mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _destroySelected: =>
    for item in @props.selection.items()
      Actions.destroyDraft(item)
    @props.selection.clear()
    return

module.exports = {DraftDeleteButton}
