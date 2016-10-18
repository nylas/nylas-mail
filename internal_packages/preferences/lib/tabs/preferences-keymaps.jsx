import React from 'react';
import path from 'path';
import fs from 'fs';
import { remote } from 'electron';
import { Flexbox } from 'nylas-component-kit';

import displayedKeybindings from './keymaps/displayed-keybindings';
import CommandItem from './keymaps/command-item';

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
        bindings[command] = NylasEnv.keymaps.getBindingsForCommand(command) || [];
      }
    }
    return bindings;
  }

  _loadTemplates() {
    const templatesDir = path.join(NylasEnv.getLoadSettings().resourcePath, 'keymaps', 'templates');
    fs.readdir(templatesDir, (err, files) => {
      if (!files || !(files instanceof Array)) return;
      let templates = files.filter((filename) => {
        return path.extname(filename) === '.json';
      });
      templates = templates.map((filename) => {
        return path.parse(filename).name;
      });
      this.setState({templates: templates});
    });
  }

  _onShowUserKeymaps() {
    const keymapsFile = NylasEnv.keymaps.getUserKeymapPath();
    if (!fs.existsSync(keymapsFile)) {
      fs.writeFileSync(keymapsFile, '{}');
    }
    remote.shell.showItemInFolder(keymapsFile);
  }

  _onDeleteUserKeymap() {
    const chosen = remote.dialog.showMessageBox(NylasEnv.getCurrentWindow(), {
      type: 'info',
      message: "Are you sure?",
      detail: "Delete your custom key bindings and reset to the template defaults?",
      buttons: ['Cancel', 'Reset'],
    });

    if (chosen === 1) {
      const keymapsFile = NylasEnv.keymaps.getUserKeymapPath();
      fs.writeFileSync(keymapsFile, '{}');
    }
  }

  _renderBindingsSection = (section) => {
    return (
      <section key={`section-${section.title}`}>
        <div className="shortcut-section-title">{section.title}</div>
        {
          section.items.map(([command, label]) => {
            return (
              <CommandItem
                key={command}
                command={command}
                label={label}
                bindings={this.state.bindings[command]}
              />
            );
          })
        }
      </section>
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
                tabIndex={-1}
                value={this.props.config.get('core.keymapTemplate')}
                onChange={(event) => this.props.config.set('core.keymapTemplate', event.target.value)}
              >
                {this.state.templates.map((template) => {
                  return <option key={template} value={template}>{template}</option>
                })}
              </select>
            </div>
            <div style={{flex: 1}} />
            <button className="btn" onClick={this._onDeleteUserKeymap}>Reset to Defaults</button>
          </Flexbox>
          <p>
            You can choose a shortcut set to use keyboard shortcuts of familiar email clients.
            To edit a shortcut, click it in the list below and enter a replacement on the keyboard.
          </p>
          {displayedKeybindings.map(this._renderBindingsSection)}
        </section>
        <section>
          <h2>Customization</h2>
          <p>You can manage your custom shortcuts directly by editing your shortcuts file.</p>
          <button className="btn" onClick={this._onShowUserKeymaps}>Edit custom shortcuts</button>
        </section>
      </div>
    );
  }

}

export default PreferencesKeymaps;
