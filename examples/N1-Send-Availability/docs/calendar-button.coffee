{Utils, DraftStore, React} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class CalendarButton extends React.Component
  @displayName: 'CalendarButton'

  render: =>
    React.createElement("div", {"className": "btn btn-toolbar", "onClick": (@_onClick)}, """
      Add Availability
""")

  _onClick: =>
    BrowserWindow = require('remote').require('browser-window')
    w = new BrowserWindow
      'node-integration': false,
      'web-preferences': {'web-security':false},
      'width': 700,
      'height': 600

    # Here, we load an arbitrary html file into the Composer!
    path = require 'path'
    url = path.join __dirname, '..', 'calendar.html'
    w.loadUrl "file://#{url}?draftClientId=#{@props.draftClientId}"


  _getDialog: =>
    require('remote').require('dialog')


module.exports = CalendarButton
