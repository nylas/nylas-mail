_ = require 'underscore-plus'
React = require 'react'
{Actions, Utils} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class ArchiveButton extends React.Component
  @displayName: "ArchiveButton"

  render: =>
    <button className="btn btn-toolbar btn-archive"
            data-tooltip="Archive"
            onClick={@_onArchive}>
      <RetinaImg name="toolbar-archive.png" />
    </button>

  _onArchive: (e) =>
    return unless Utils.nodeIsVisible(e.currentTarget)
    Actions.archive()
    e.stopPropagation()


module.exports = ArchiveButton
