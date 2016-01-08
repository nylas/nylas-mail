React = require 'react'
{RetinaImg, Flexbox} = require 'nylas-component-kit'
{LaunchServices, AccountStore} = require 'nylas-exports'
ConfigSchemaItem = require './config-schema-item'

class DefaultMailClientItem extends React.Component
  constructor: (@props) ->
    @state = {}
    @_services = new LaunchServices()
    if @_services.available()
      @_services.isRegisteredForURLScheme 'mailto', (registered) =>
        @setState(defaultClient: registered)

  render: =>
    return false unless process.platform is 'darwin'
    <div className="item">
      <input type="checkbox" id="default-client" checked={@state.defaultClient} onChange={@toggleDefaultMailClient}/>
      <label htmlFor="default-client">Use Nylas as my default mail client</label>
    </div>

  toggleDefaultMailClient: (event) =>
    if @state.defaultClient is true
      @setState(defaultClient: false)
      @_services.resetURLScheme('mailto')
    else
      @setState(defaultClient: true)
      @_services.registerForURLScheme('mailto')
    event.target.blur()

class AppearanceModeSwitch extends React.Component
  @displayName: 'AppearanceModeSwitch'
  @propTypes:
    config: React.PropTypes.object.isRequired

  constructor: (@props) ->
    @state = {
      value: @props.config.get('core.workspace.mode')
    }

  componentWillReceiveProps: (nextProps) ->
    @setState({
      value: nextProps.config.get('core.workspace.mode')
    })

  render: ->
    hasChanges = @state.value isnt @props.config.get('core.workspace.mode')
    applyChangesClass = "btn btn-small"
    applyChangesClass += " btn-disabled" unless hasChanges

    <div className="appearance-mode-switch">
      <Flexbox
        direction="row"
        style={alignItems: "center"}
        className="item">
        {@_renderModeOptions()}
      </Flexbox>
      <div className={applyChangesClass} onClick={@_onApplyChanges}>Apply Changes</div>
    </div>

  _renderModeOptions: ->
    ['list', 'split'].map (mode) =>
      <AppearanceModeOption
        mode={mode}
        key={mode}
        active={@state.value is mode}
        onClick={ => @setState(value: mode) } />

  _onApplyChanges: =>
    @props.config.set('core.workspace.mode', @state.value)


class AppearanceModeOption extends React.Component
  @propTypes:
    mode: React.PropTypes.string.isRequired
    active: React.PropTypes.bool
    onClick: React.PropTypes.func

  constructor: (@props) ->

  render: =>
    classname = "appearance-mode"
    classname += " active" if @props.active

    label = {
      'list': 'Single Panel'
      'split': 'Two Panel'
    }[@props.mode]

    <div className={classname} onClick={@props.onClick}>
      <RetinaImg name={"appearance-mode-#{@props.mode}.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      <div>{label}</div>
    </div>

class ThemeSelector extends React.Component
  constructor: (@props) ->
    @_themeManager = NylasEnv.themes
    @state = @_getState()

  componentDidMount: =>
    @disposable = @_themeManager.onDidChangeActiveThemes =>
      @setState @_getState()

  componentWillUnmount: ->
    @disposable.dispose()

  _getState: =>
    themes: @_themeManager.getLoadedThemes()
    activeTheme: @_themeManager.getActiveTheme().name

  _setActiveTheme: (theme) =>
    @setState activeTheme: theme
    @_themeManager.setActiveTheme theme

  _onChangeTheme: (event) =>
    value = event.target.value
    if value is 'install'
      NylasEnv.commands.dispatch document.body, 'application:install-package'
    else
      @_setActiveTheme(value)

  render: =>
    <div className="item">
      <span>Select theme: </span>
      <select value={@state.activeTheme} onChange={@_onChangeTheme}>
        {@state.themes.map (theme) ->
          <option key={theme.name} value={theme.name}>{theme.displayName}</option>}
        <option value="install">Install a theme...</option>
      </select>
    </div>

class WorkspaceSection extends React.Component
  @displayName: 'WorkspaceSection'
  @propTypes:
    config: React.PropTypes.object
    configSchema: React.PropTypes.object

  render: =>
    <section>
      <h2>Workspace</h2>
      <DefaultMailClientItem />

      <ConfigSchemaItem
        configSchema={@props.configSchema.properties.workspace.properties.systemTray}
        keyPath="core.workspace.systemTray"
        config={@props.config} />

      <ConfigSchemaItem
        configSchema={@props.configSchema.properties.workspace.properties.showImportant}
        keyPath="core.workspace.showImportant"
        config={@props.config} />

      <ConfigSchemaItem
        configSchema={@props.configSchema.properties.workspace.properties.showUnreadForAllCategories}
        keyPath="core.workspace.showUnreadForAllCategories"
        config={@props.config} />

      <ConfigSchemaItem
        configSchema={@props.configSchema.properties.workspace.properties.interfaceZoom}
        keyPath="core.workspace.interfaceZoom"
        config={@props.config} />

      <ThemeSelector />

      <h2>Layout</h2>

      <AppearanceModeSwitch config={@props.config} />
    </section>

module.exports = WorkspaceSection
