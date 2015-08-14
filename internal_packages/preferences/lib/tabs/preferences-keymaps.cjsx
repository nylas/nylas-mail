React = require 'react'
_ = require 'underscore'
path = require 'path'
fs = require 'fs'
{RetinaImg, Flexbox} = require 'nylas-component-kit'

DisplayedKeybindings = [
  ['application:new-message', 'New Message'],
  ['application:reply', 'Reply'],
  ['application:reply-all', 'Reply All'],
  ['application:forward', 'Forward'],
  ['application:focus-search', 'Search'],
  ['application:change-category', 'Change Folder / Labels'],
  ['core:select-item', 'Select Focused Item'],
  ['core:star-item', 'Star Focused Item'],
]

class PreferencesKeymaps extends React.Component
  @displayName: 'PreferencesKeymaps'

  constructor: (@props) ->
    @state =
      templates: []
      bindings: @_getStateFromKeymaps()
    @_loadTemplates()

  componentDidMount: =>
    @unsubscribe = atom.keymaps.onDidReloadKeymap =>
      @setState(bindings: @_getStateFromKeymaps())

  componentWillUnmount: =>
    @unsubscribe?()

  _loadTemplates: =>
    templatesDir = path.join(atom.getLoadSettings().resourcePath, 'keymaps', 'templates')
    fs.readdir templatesDir, (err, files) =>
      return unless files and files instanceof Array
      templates = files.filter (filename) =>
        path.extname(filename) is '.cson'
      @setState(templates: templates)

  _getStateFromKeymaps: =>
    bindings = {}
    for [command, label] in DisplayedKeybindings
      [found] = atom.keymaps.findKeyBindings(command: command, target: document.body) || []
      bindings[command] = found
    bindings

  render: =>
    <div className="container-keymaps">
      <Flexbox className="shortcut shortcut-select">
        <div className="shortcut-name">Keyboard shortcut set:</div>
        <div className="shortcut-value">
          <select
            style={margin:0}
            value={@props.config.get('core.keymapTemplate')}
            onChange={ (event) => @props.config.set('core.keymapTemplate', event.target.value) }>
          { @state.templates.map (template) =>
            <option key={template} value={template}>{path.basename(template, '.cson')}</option>
          }
          </select>
        </div>
      </Flexbox>
      {@_renderBindings()}

      <div className="shortcuts-extras">
        <button className="btn" onClick={@_onShowUserKeymaps}>Edit custom shortcuts</button>
      </div>
    </div>

  _renderBindingFor: ([command, label]) =>
    description = "None"
    if @state.bindings[command]
      {keystrokes} = @state.bindings[command]
      description = keystrokes.replace(/-/gi,'').replace(/cmd/gi, '⌘').replace(/alt/gi, '⌥').replace(/shift/gi, '⇧').replace(/ctrl/gi, '^').toUpperCase()

    <Flexbox className="shortcut" key={command}>
      <div className="shortcut-name">{label}</div>
      <div className="shortcut-value">{description}</div>
    </Flexbox>

  _renderBindings: =>
    DisplayedKeybindings.map(@_renderBindingFor)

  _onShowUserKeymaps: =>
    require('shell').openItem(atom.keymaps.getUserKeymapPath())

module.exports = PreferencesKeymaps
