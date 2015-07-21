_ = require 'underscore'
React = require 'react'
{Actions, DOMUtils} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class ThreadArchiveButton extends React.Component
  @displayName: "ThreadArchiveButton"

  render: =>
    <button className="btn btn-toolbar btn-archive"
            data-tooltip="Archive"
            onClick={@_onArchive}>
      <RetinaImg name="toolbar-archive.png" mode={RetinaImg.Mode.ContentIsMask}/>
    </button>

  _onArchive: (e) =>
    return unless DOMUtils.nodeIsVisible(e.currentTarget)
    Actions.archive()
    e.stopPropagation()


module.exports = ThreadArchiveButton
