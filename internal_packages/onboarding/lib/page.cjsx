React = require 'react'
{RetinaImg} = require 'nylas-component-kit'

class Page extends React.Component
  @displayName: "Page"

  constructor: (@props) ->

  _renderClose: (action="close") ->
    if action is "close"
      onClick = -> atom.close()
    else if action is "quit"
      onClick = ->
        require('ipc').send('command', 'application:quit')
    else onClick = ->

    <div className="quit" onClick={onClick}>
      <RetinaImg name="onboarding-close.png" mode={RetinaImg.Mode.ContentPreserve}/>
    </div>

  _renderSpinner: ->
    styles =
      position: "absolute"
      zIndex: 10
      top: "50%"
      left: "50%"
      transform: 'translate(-50%, -50%)'

    <RetinaImg ref="spinner"
               style={styles}
               name="Setup-Spinner.gif"
               mode={RetinaImg.Mode.ContentPreserve}/>

module.exports = Page
