{Utils, DraftStore, React} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class CalendarButton extends React.Component
  @displayName: 'CalendarButton'

  render: =>
    <button className="btn btn-toolbar" onClick={@_onClick} title="Quick schedule">
      <RetinaImg url="nylas://quick-schedule/assets/icon-composer-quickschedule@2x.png" mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onClick: =>
    BrowserWindow = require('electron').remote.BrowserWindow
    w = new BrowserWindow
      title: 'N1 Quick Schedule'
      nodeIntegration: false
      webPreferences:
        webSecurity:false
      width: 800
      height: 650

    # Here, we load an arbitrary html file into the Composer!
    path = require 'path'
    url = path.join __dirname, '..', 'calendar.html'
    w.loadURL "file://#{url}?draftClientId=#{@props.draftClientId}"


  _getDialog: =>
    require('remote').require('dialog')


module.exports = CalendarButton
