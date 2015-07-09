React = require "react/addons"
classNames = require 'classnames'
DraftListStore = require './draft-list-store'
{RetinaImg} = require 'nylas-component-kit'
{Actions, FocusedContentStore} = require "nylas-exports"

class DraftDeleteButton extends React.Component
  @displayName: 'DraftDeleteButton'
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  render: ->
    <button style={order:-100}
            className="btn btn-toolbar"
            data-tooltip="Delete"
            onClick={@_destroyDraft}>
      <RetinaImg name="icon-composer-trash.png" mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _destroyDraft: =>
    Actions.deleteSelection()

module.exports = {DraftDeleteButton}
