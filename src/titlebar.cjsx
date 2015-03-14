React = require 'react'

module.exports =
TitleBar = React.createClass
  displayName: 'TitleBar'

  render: ->
    <div name="TitleBar" className="sheet-title-bar">
      {atom.getCurrentWindow().getTitle()}
      <button className="close" onClick={ -> atom.close()}></button>
      <button className="minimize" onClick={ -> atom.minimize()}></button>
      <button className="maximize" onClick={ -> atom.maximize()}></button>
    </div>
