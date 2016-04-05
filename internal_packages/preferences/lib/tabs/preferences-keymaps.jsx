import React from 'react';
import _ from 'underscore';
import path from 'path';
import fs from 'fs';
import shell from 'shell';

import {Flexbox} from 'nylas-component-kit';

const displayedKeybindings = [
  {
    title: 'Application',
    items: [
      ['application:new-message', 'New Message'],
      ['application:focus-search', 'Search'],
    ],
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
    ],
  },
  {
    title: 'Composer',
    items: [
      ['composer:send-message', 'Send Message'],
      ['composer:focus-to', 'Focus the To field'],
      ['composer:show-and-focus-cc', 'Focus the Cc field'],
      ['composer:show-and-focus-bcc', 'Focus the Bcc field'],
    ],
  },
  {
    title: 'Navigation',
    items: [
      ['application:pop-sheet', 'Return to conversation list'],
      ['core:focus-item', 'Open selected conversation'],
      ['core:previous-item', 'Move to newer conversation'],
      ['core:next-item', 'Move to older conversation'],
    ],
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
    ],
  },
  {
    title: 'Jumping',
    items: [
      ['navigation:go-to-inbox', 'Go to "Inbox"'],
      ['navigation:go-to-starred', 'Go to "Starred"'],
      ['navigation:go-to-sent', 'Go to "Sent Mail"'],
      ['navigation:go-to-drafts', 'Go to "Drafts"'],
      ['navigation:go-to-all', 'Go to "All Mail"'],
    ],
  },
]


class PreferencesKeymaps extends React.Component {

  static displayName = 'PreferencesKeymaps';

  static propTypes = {
    config: React.PropTypes.object,
  };

  constructor() {
    super();
    this.state = {
      templates: [],
      bindings: this._getStateFromKeymaps(),
    };
    this._loadTemplates();
  }

  componentDidMount() {
    this._disposable = NylasEnv.keymaps.onDidReloadKeymap(() => {
      this.setState({bindings: this._getStateFromKeymaps()});
    });
  }

  componentWillUnmount() {
    this._disposable.dispose();
  }

  _getStateFromKeymaps() {
    const bindings = {};
    for (const section of displayedKeybindings) {
      for (const [command] of section.items) {
        const keyBinding = NylasEnv.keymaps.findKeyBindings({command: command});
        bindings[command] = keyBinding ? keyBinding : [];
      }
    }
    return bindings;
  }

  _loadTemplates() {
    const templatesDir = path.join(NylasEnv.getLoadSettings().resourcePath, 'keymaps', 'templates');
    fs.readdir(templatesDir, (err, files) => {
      if (!files || !files instanceof Array) return;
      let templates = files.filter((filename) => {
        return path.extname(filename) === '.cson' || path.extname(filename) === '.json';
      });
      templates = templates.map((filename) => {
        return path.parse(filename).name;
      });
      this.setState({templates: templates});
    });
  }

  _formatKeystrokes(original) {
    // On Windows, display cmd-shift-c
    if (process.platform === "win32") return original;

    // Replace "cmd" => ⌘, etc.
    const modifiers = [
      [/-(?!$)/gi, ''],
      [/cmd/gi, '⌘'],
      [/alt/gi, '⌥'],
      [/shift/gi, '⇧'],
      [/ctrl/gi, '^'],
    ];
    let clean = original;
    for (const [regexp, char] of modifiers) {
      clean = clean.replace(regexp, char);
    }

    // ⌘⇧c => ⌘⇧C
    if (clean !== original) {
      clean = clean.toUpperCase();
    }

    // backspace => Backspace
    if (original.length > 1 && clean === original) {
      clean = clean[0].toUpperCase() + clean.slice(1);
    }
    return clean;
  }

  _onShowUserKeymaps() {
    const keymapsFile = NylasEnv.keymaps.getUserKeymapPath();
    if (!fs.existsSync(keymapsFile)) {
      fs.writeSync(fs.openSync(keymapsFile, 'w'), '');
    }
    shell.showItemInFolder(keymapsFile);
  }

  _renderBindingsSection = (section) => {
    return (
      <section key={`section-${section.title}`}>
        <div className="shortcut-section-title">{section.title}</div>
        {section.items.map(this._renderBindingFor)}
      </section>
    );
  }

  _renderBindingFor = ([command, label]) => {
    const descriptions = [];
    if (this.state.bindings[command]) {
      for (const binding of this.state.bindings[command]) {
        descriptions.push(binding.keystrokes);
      }
    }

    let value = "None";
    if (descriptions.length > 0) {
      value = _.uniq(descriptions).map(this._renderKeystrokes);
    }

    return (
      <Flexbox className="shortcut" key={command}>
        <div className="col-left shortcut-name">{label}</div>
        <div className="col-right">{value}</div>
      </Flexbox>
    );
  }

  _renderKeystrokes = (keystrokes, idx) => {
    const elements = [];
    const splitKeystrokes = keystrokes.split(' ');
    splitKeystrokes.forEach((keystroke) => {
      elements.push(<span key={keystroke}>{this._formatKeystrokes(keystroke)}</span>);
    });
    return (
      <span key={`keystrokes-${idx}`} className="shortcut-value">{elements}</span>
    );
  }

  render() {
    return (
      <div className="container-keymaps">
        <section>
          <Flexbox className="container-dropdown">
            <div>Shortcut set:</div>
            <div className="dropdown">
              <select
                style={{margin: 0}}
                value={this.props.config.get('core.keymapTemplate')}
                onChange={(event) => this.props.config.set('core.keymapTemplate', event.target.value)}>
                {this.state.templates.map((template) => {
                  return <option key={template} value={template}>{template}</option>
                })}
              </select>
            </div>
          </Flexbox>
          <p>You can choose a shortcut set to use keyboard shortcuts of familiar email clients.</p>
          {displayedKeybindings.map(this._renderBindingsSection)}
        </section>
        <section>
          <h2>Customization</h2>
          <p>Define additional shortcuts by adding them to your shortcuts file.</p>
          <button className="btn" onClick={this._onShowUserKeymaps}>Edit custom shortcuts</button>
        </section>
      </div>
    );
  }

}

export default PreferencesKeymaps;
