_ = require 'underscore'
React = require 'react'
{ListTabular, MultiselectList} = require 'nylas-component-kit'
{Actions,
 DatabaseStore,
 ComponentRegistry} = require 'nylas-exports'
FileListStore = require './file-list-store'

class FileList extends React.Component
  @displayName: 'FileList'

  @containerRequired: false

  componentWillMount: =>
    prettySize = (size) ->
      units = ['GB', 'MB', 'KB', 'bytes']
      while size > 1024
        size /= 1024
        units.pop()
      size = "#{(Math.ceil(size * 10) / 10)}"
      pretty = units.pop()
      "#{size} #{pretty}"

    c1 = new ListTabular.Column
      name: "Name"
      flex: 1
      resolver: (file) =>
        <div>{file.filename}</div>

    c2 = new ListTabular.Column
      name: "Size"
      width: '100px'
      resolver: (file) =>
        <div>{prettySize(file.size)}</div>

    @columns = [c1, c2]

  render: =>
    <MultiselectList
      dataStore={FileListStore}
      columns={@columns}
      commands={{}}
      onDoubleClick={@_onDoubleClick}
      itemPropsProvider={ -> {} }
      className="file-list"
      collection="file" />

  _onDoubleClick: (item) =>


module.exports = FileList
