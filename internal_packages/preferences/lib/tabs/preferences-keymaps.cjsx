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
  ['application:star-item', 'Star Focused Item'],
]

class PreferencesKeymaps extends React.Component
  @displayName: 'PreferencesKeymaps'

  constructor: (@props) ->
    @state =
      templates: []
      bindings: @_getStateFromKeymaps()
    @_loadTemplates()

  componentDidMount: =>
    @_disposable = NylasEnv.keymaps.onDidReloadKeymap =>
      @setState(bindings: @_getStateFromKeymaps())

  componentWillUnmount: =>
    @_disposable.dispose()

  _loadTemplates: =>
    templatesDir = path.join(NylasEnv.getLoadSettings().resourcePath, 'keymaps', 'templates')
    fs.readdir templatesDir, (err, files) =>
      return unless files and files instanceof Array
      templates = files.filter (filename) =>
        path.extname(filename) is '.cson' or  path.extname(filename) is '.json'
      templates = templates.map (filename) =>
        path.parse(filename).name
      @setState(templates: templates)

  _getStateFromKeymaps: =>
    bindings = {}
    for [command, label] in DisplayedKeybindings
      bindings[command] = NylasEnv.keymaps.findKeyBindings(command: command, target: document.body) || []
    bindings

  render: =>
    <div className="container-keymaps">
      <section>
        <h2>Shortcuts</h2>
        <Flexbox className="shortcut shortcut-select">
          <div className="shortcut-name">Keyboard shortcut set:</div>
          <div className="shortcut-value">
            <select
              style={margin:0}
              value={@props.config.get('core.keymapTemplate')}
              onChange={ (event) => @props.config.set('core.keymapTemplate', event.target.value) }>
            { @state.templates.map (template) =>
              <option key={template} value={template}>{template}</option>
            }
            </select>
          </div>
        </Flexbox>
        {@_renderBindings()}
      </section>
      <section>
        <h2>Customization</h2>
        <p>Define additional shortcuts by adding them to your shortcuts file.</p>
        <button className="btn" onClick={@_onShowUserKeymaps}>Edit custom shortcuts</button>
      </section>
    </div>

  _renderBindingFor: ([command, label]) =>
    descriptions = []
    if @state.bindings[command]
      for binding in @state.bindings[command]
        descriptions.push(@_formatKeystrokes(binding.keystrokes))

    if descriptions.length is 0
      value = 'None'
    else
      value = _.uniq(descriptions).join(', ')

    <Flexbox className="shortcut" key={command}>
      <div className="shortcut-name">{label}</div>
      <div className="shortcut-value">{value}</div>
    </Flexbox>

  _renderBindings: =>
    DisplayedKeybindings.map(@_renderBindingFor)

  _formatKeystrokes: (keystrokes) ->
    if process.platform is 'win32'
      # On Windows, display cmd-shift-c
      return keystrokes
    else
      # On Mac and Linux, display ⌘⇧C
      return keystrokes.replace(/-/gi,'').replace(/cmd/gi, '⌘').replace(/alt/gi, '⌥').replace(/shift/gi, '⇧').replace(/ctrl/gi, '^').toUpperCase()

  _onShowUserKeymaps: =>
    keymapsFile = NylasEnv.keymaps.getUserKeymapPath()
    if !fs.existsSync(keymapsFile)
      fs.writeSync(fs.openSync(keymapsFile, 'w'), '')
    require('shell').showItemInFolder(keymapsFile)

module.exports = PreferencesKeymaps
