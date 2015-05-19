React = require 'react'
_ = require "underscore"
{Utils, FileDownloadStore, Actions} = require 'nylas-exports'
{Spinner, EventedIFrame} = require 'nylas-component-kit'
FileFrameStore = require './file-frame-store'

class FileFrame extends React.Component
  @displayName: 'FileFrame'

  render: =>
    src = if @state.ready then @state.filepath else ''
    if @state.file
      <div className="file-frame-container">
        <EventedIFrame src={src} />
        <Spinner visible={!@state.ready} />
      </div>
    else
      <div></div>

  constructor: (@props) ->
    @state = @getStateFromStores()

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push FileFrameStore.listen @_onChange

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  getStateFromStores: =>
    file: FileFrameStore.file()
    filepath: FileDownloadStore.pathForFile(FileFrameStore.file())
    ready: FileFrameStore.ready()

  _onChange: =>
    @setState(@getStateFromStores())


module.exports = FileFrame
