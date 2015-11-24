{Utils, DraftStore, React} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class CalendarButton extends React.Component
  @displayName: 'CalendarButton'

  render: =>
    <button className="btn btn-toolbar" onClick={@_onClick}>
      Add Availability
    </button>

  _onClick: =>
    BrowserWindow = require('remote').require('browser-window')
    w = new BrowserWindow
      nodeIntegration: false
      webPreferences:
        webSecurity:false
      width: 700
      height: 600

    # Here, we load an arbitrary html file into the Composer!
    path = require 'path'
    url = path.join __dirname, '..', 'calendar.html'
    w.loadURL "file://#{url}?draftClientId=#{@props.draftClientId}"


  _getDialog: =>
    require('remote').require('dialog')


module.exports = CalendarButton
