React = require 'react'
_ = require 'underscore'
path = require 'path'
fs = require 'fs'
{RetinaImg, Flexbox} = require 'nylas-component-kit'

DisplayedKeybindings = [
  {
    title: 'Application',
    items: [
      ['application:new-message', 'New Message'],
      ['application:focus-search', 'Search'],
    ]
  },
  {
    title: 'Actions',
    items: [
      ['application:reply', 'Reply'],
      ['application:reply-all', 'Reply All'],
      ['application:forward', 'Forward'],
      ['application:archive-item', 'Archive'],
      ['application:delete-item', 'Trash'],
      ['application:remove-from-view', 'Remove from view'],
      ['application:gmail-remove-from-view', 'Gmail Remove from view'],
      ['application:star-item', 'Star'],
      ['application:change-category', 'Change Folder / Labels'],
      ['application:mark-as-read', 'Mark as read'],
      ['application:mark-as-unread', 'Mark as unread'],
      ['application:mark-important', 'Mark as important (Gmail)'],
      ['application:mark-unimportant', 'Mark as unimportant (Gmail)'],
      ['application:remove-and-previous', 'Remove from view and previous'],
      ['application:remove-and-next', 'Remove from view and next'],
    ]
  },
  {
    title: 'Composer',
    items: [
      ['composer:send-message', 'Send Message'],
      ['composer:focus-to', 'Focus the To field'],
      ['composer:show-and-focus-cc', 'Focus the Cc field'],
      ['composer:show-and-focus-bcc', 'Focus the Bcc field']
    ]
  },
  {
    title: 'Navigation',
    items: [
      ['application:pop-sheet', 'Return to conversation list'],
      ['core:focus-item', 'Open selected conversation'],
      ['core:previous-item', 'Move to newer conversation'],
      ['core:next-item', 'Move to older conversation'],
    ]
  },
  {
    title: 'Selection',
    items: [
      ['core:select-item', 'Select conversation'],
      ['multiselect-list:select-all', 'Select all conversations'],
      ['multiselect-list:deselect-all', 'Deselect all conversations'],
      ['thread-list:select-read', 'Select all read conversations'],
      ['thread-list:select-unread', 'Select all unread conversations'],
      ['thread-list:select-starred', 'Select all starred conversations'],
      ['thread-list:select-unstarred', 'Select all unstarred conversations'],
    ]
  },
  {
    title: 'Jumping',
    items: [
      ['navigation:go-to-inbox', 'Go to "Inbox"'],
      ['navigation:go-to-starred', 'Go to "Starred"'],
      ['navigation:go-to-sent', 'Go to "Sent Mail"'],
      ['navigation:go-to-drafts', 'Go to "Drafts"'],
      ['navigation:go-to-all', 'Go to "All Mail"'],
    ]
  }
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
    for section in DisplayedKeybindings
      for [command, label] in section.items
        bindings[command] = NylasEnv.keymaps.findKeyBindings(command: command) || []
    bindings

  render: =>
    <div className="container-keymaps">
      <section>
        <h2>Shortcuts</h2>
        <Flexbox className="shortcut-presets">
          <div className="col-left">Keyboard shortcut set:</div>
          <div className="col-right">
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
        {
          DisplayedKeybindings.map(@_renderBindingsSection)
        }
      </section>
      <section>
        <h2>Customization</h2>
        <p>Define additional shortcuts by adding them to your shortcuts file.</p>
        <button className="btn" onClick={@_onShowUserKeymaps}>Edit custom shortcuts</button>
      </section>
    </div>

  _renderBindingsSection: (section) =>
    <section>
      <div className="shortcut-section-title">{section.title}</div>
      {
        section.items.map(@_renderBindingFor)
      }
    </section>

  _renderBindingFor: ([command, label]) =>
    descriptions = []
    if @state.bindings[command]
      for binding in @state.bindings[command]
        descriptions.push(binding.keystrokes)

    if descriptions.length is 0
      value = 'None'
    else
      value = _.uniq(descriptions).map(@_renderKeystrokes)

    <Flexbox className="shortcut" key={command}>
      <div className="col-left shortcut-name">{label}</div>
      <div className="col-right">{value}</div>
    </Flexbox>

  _renderKeystrokes: (keystrokes) =>
    elements = []
    keystrokes = keystrokes.split(' ')

    for keystroke, idx in keystrokes
      elements.push <span>{@_formatKeystrokes(keystroke)}</span>
      elements.push <span className="then"> then </span> unless idx is keystrokes.length - 1

    <span className="shortcut-value">{elements}</span>

  _formatKeystrokes: (original) =>
    if process.platform is 'win32'
      # On Windows, display cmd-shift-c
      return original

    else
      # Replace "cmd" => ⌘, etc.
      modifiers = [[/-(?!$)/gi,''], [/cmd/gi, '⌘'], [/alt/gi, '⌥'], [/shift/gi, '⇧'], [/ctrl/gi, '^']]
      clean = original
      for [regexp, char] in modifiers
        clean = clean.replace(regexp, char)

      # ⌘⇧c => ⌘⇧C
      if clean isnt original
        clean = clean.toUpperCase()

      # backspace => Backspace
      if original.length > 1 and clean is original
        clean = clean[0].toUpperCase() + clean[1..-1]
      return clean

  _onShowUserKeymaps: =>
    keymapsFile = NylasEnv.keymaps.getUserKeymapPath()
    if !fs.existsSync(keymapsFile)
      fs.writeSync(fs.openSync(keymapsFile, 'w'), '')
    require('shell').showItemInFolder(keymapsFile)

module.exports = PreferencesKeymaps
