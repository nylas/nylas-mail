React = require 'react'
path = require 'path'
fs = require 'fs'
_ = require 'underscore'
{RetinaImg, Flexbox, ConfigPropContainer} = require 'nylas-component-kit'
{EdgehillAPI} = require 'nylas-exports'
OnboardingActions = require './onboarding-actions'

# NOTE: Temporarily copied from preferences module
class AppearanceModeOption extends React.Component
  @propTypes:
    mode: React.PropTypes.string.isRequired
    active: React.PropTypes.bool
    onClick: React.PropTypes.func

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


class InitialPreferencesOptions extends React.Component
  @propTypes:
    config: React.PropTypes.object

  constructor: (@props) ->
    @state =
      templates: []
    @_loadTemplates()

  _loadTemplates: =>
    templatesDir = path.join(NylasEnv.getLoadSettings().resourcePath, 'keymaps', 'templates')
    fs.readdir templatesDir, (err, files) =>
      return unless files and files instanceof Array
      templates = files.filter (filename) =>
        path.extname(filename) is '.cson' or path.extname(filename) is '.json'
      templates = templates.map (filename) =>
        path.parse(filename).name
      @setState(templates: templates)
      @_setConfigDefaultsForAccount(templates)

  _setConfigDefaultsForAccount: (templates) =>
    return unless @props.account

    templateWithBasename = (name) =>
      _.find templates, (t) -> t.indexOf(name) is 0

    if @props.account.provider is 'gmail'
      @props.config.set('core.workspace.mode', 'list')
      @props.config.set('core.keymapTemplate', templateWithBasename('Gmail'))
    else if @props.account.provider is 'eas'
      @props.config.set('core.workspace.mode', 'split')
      @props.config.set('core.keymapTemplate', templateWithBasename('Outlook'))
    else
      @props.config.set('core.workspace.mode', 'split')
      if process.platform is 'darwin'
        @props.config.set('core.keymapTemplate', templateWithBasename('Apple Mail'))
      else
        @props.config.set('core.keymapTemplate', templateWithBasename('Outlook'))

  render: =>
    return false unless @props.config

    <div style={display:'flex', width:600, marginBottom: 50, marginLeft:150, marginRight: 150, textAlign: 'left'}>
      <div style={flex:1}>
        <p>
          Do you prefer a single panel layout (like Gmail)
          or a two panel layout?
        </p>
        <Flexbox direction="row" style={alignItems: "center"}>
          {['list', 'split'].map (mode) =>
            <AppearanceModeOption
              mode={mode} key={mode}
              active={@props.config.get('core.workspace.mode') is mode}
              onClick={ => @props.config.set('core.workspace.mode', mode)} />
          }
        </Flexbox>
      </div>
      <div key="divider" style={marginLeft:20, marginRight:20, borderLeft:'1px solid #ccc'}></div>
      <div style={flex:1}>
        <p>
          We've picked a set of keyboard shortcuts based on your email
          account and platform. You can also pick another set:
        </p>
        <select
          style={margin:0}
          value={@props.config.get('core.keymapTemplate')}
          onChange={ (event) => @props.config.set('core.keymapTemplate', event.target.value) }>
        { @state.templates.map (template) =>
          <option key={template} value={template}>{template}</option>
        }
        </select>
      </div>

    </div>


class InitialPreferencesPage extends React.Component
  @displayName: "InitialPreferencesPage"

  render: =>
    <div className="page opaque" style={width:900, height:620}>
      <h1 style={paddingTop: 100}>Welcome to N1</h1>
      <h4 style={marginBottom: 70}>Let's set things up to your liking.</h4>
      <ConfigPropContainer>
        <InitialPreferencesOptions account={@props.pageData.account} />
      </ConfigPropContainer>
      <button className="btn btn-large" style={marginBottom:60} onClick={@_onNextPage}>Looks Good!</button>
    </div>

  _onNextPage: =>
    OnboardingActions.moveToPage("initial-packages")

module.exports = InitialPreferencesPage
