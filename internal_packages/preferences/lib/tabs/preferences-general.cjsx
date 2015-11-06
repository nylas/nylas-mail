React = require 'react'
_ = require 'underscore'
{RetinaImg, Flexbox} = require 'nylas-component-kit'
{LaunchServices, AccountStore} = require 'nylas-exports'

class PreferencesGeneral extends React.Component
  @displayName: 'PreferencesGeneral'

  constructor: (@props) ->
    @state = {}

    @_services = new LaunchServices()
    if @_services.available()
      @_services.isRegisteredForURLScheme 'mailto', (registered) =>
        @setState(defaultClient: registered)

  toggleDefaultMailClient: =>
    if @state.defaultClient is true
      @setState(defaultClient: false)
      @_services.resetURLScheme('mailto')
    else
      @setState(defaultClient: true)
      @_services.registerForURLScheme('mailto')

  toggleShowImportant: (event) =>
    @props.config.toggle('core.showImportant')
    event.preventDefault()

  toggleShowSystemTrayIcon: (event) =>
    @props.config.toggle('core.showSystemTray')
    event.preventDefault()

  _renderImportanceOptionElement: =>
    return false unless AccountStore.current()?.usesImportantFlag()
    importanceOptionElement = <div className="section-header">
      <input type="checkbox" id="show-important"
             checked={@props.config.get('core.showImportant')}
             onChange={@toggleShowImportant}/>
      <label htmlFor="show-important">Show Gmail-style important markers</label>
    </div>

  render: =>
    <div className="container-notifications">
      <div className="section">
        <div className="section-header platform-darwin-only">
          <input type="checkbox" id="default-client" checked={@state.defaultClient} onChange={@toggleDefaultMailClient}/>
          <label htmlFor="default-client">Use Nylas as my default mail client</label>
        </div>

        {@_renderImportanceOptionElement()}

        <div className="section-header platform-darwin-only">
          <input type="checkbox" id="show-system-tray" checked={@props.config.get('core.showSystemTray')} onChange={@toggleShowSystemTrayIcon}/>
          <label htmlFor="show-system-tray">Show Nylas app icon in the menu bar</label>
        </div>

        <div className="section-header" style={marginTop:30}>
          Delay for marking messages as read:
          <select value={@props.config.get('core.reading.markAsReadDelay')}
                  onChange={ (event) => @props.config.set('core.reading.markAsReadDelay', event.target.value) }>
            <option value={0}>Instantly</option>
            <option value={500}>½ Second</option>
            <option value={2000}>2 Seconds</option>
          </select>
        </div>

        <div className="section-header">
          Download attachments for new mail:
          <select value={@props.config.get('core.attachments.downloadPolicy')}
                  onChange={ (event) => @props.config.set('core.attachments.downloadPolicy', event.target.value) }>
            <option value="on-receive">When Received</option>
            <option value="on-read">When Reading</option>
            <option value="manually">Manually</option>
          </select>
        </div>

        <div className="section-header">
        Default reply behavior:
          <div style={float:'right', width:138}>
            <input type="radio"
                   id="core.sending.defaultReplyType.reply"
                   checked={@props.config.get('core.sending.defaultReplyType') == 'reply'}
                   onChange={ => @props.config.set('core.sending.defaultReplyType', 'reply') }/>
            <label htmlFor="core.sending.defaultReplyType.reply">Reply</label>
            <br/>
            <input type="radio"
                   id="core.sending.defaultReplyType.replyAll"
                   checked={@props.config.get('core.sending.defaultReplyType') == 'reply-all'}
                   onChange={ => @props.config.set('core.sending.defaultReplyType', 'reply-all') }/>
            <label htmlFor="core.sending.defaultReplyType.replyAll">Reply all</label>
          </div>
        </div>
      </div>
    </div>

module.exports = PreferencesGeneral
