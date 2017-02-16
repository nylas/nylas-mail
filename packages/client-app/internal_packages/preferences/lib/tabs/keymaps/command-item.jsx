import React from 'react';
import ReactDOM from 'react-dom';
import _ from 'underscore';
import { Flexbox } from 'nylas-component-kit';
import fs from 'fs';

import {keyAndModifiersForEvent} from './mousetrap-keybinding-helpers';

export default class CommandKeybinding extends React.Component {
  static propTypes = {
    bindings: React.PropTypes.array,
    label: React.PropTypes.string,
    command: React.PropTypes.string,
  }

  constructor(props) {
    super(props);

    this.state = {
      editing: false,
    }
  }
  componentDidUpdate() {
    const {modifiers, keys, editing} = this.state;
    if (editing) {
      const finished = (((modifiers.length > 0) && (keys.length > 0)) || (keys.length >= 2));
      if (finished) {
        ReactDOM.findDOMNode(this).blur();
      }
    }
  }

  _formatKeystrokes(original) {
    // On Windows, display cmd-shift-c
    if (process.platform === "win32") return original;

    // Replace "cmd" => ⌘, etc.
    const modifiers = [
      [/\+(?!$)/gi, ''],
      [/command/gi, '⌘'],
      [/meta/gi, '⌘'],
      [/alt/gi, '⌥'],
      [/shift/gi, '⇧'],
      [/ctrl/gi, '^'],
      [/mod/gi, (process.platform === 'darwin' ? '⌘' : '^')],
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

  _renderKeystrokes = (keystrokes, idx) => {
    const elements = [];
    const splitKeystrokes = keystrokes.split(' ');
    splitKeystrokes.forEach((keystroke, kidx) => {
      elements.push(<span key={kidx}>{this._formatKeystrokes(keystroke)}</span>);
      if (kidx < splitKeystrokes.length - 1) {
        elements.push(<span className="then" key={`then${kidx}`}> then </span>);
      }
    });
    return (
      <span key={`keystrokes-${idx}`} className="shortcut-value">{elements}</span>
    );
  }

  _onEdit = () => {
    this.setState({editing: true, editingBinding: null, keys: [], modifiers: []});
    NylasEnv.keymaps.suspendAllKeymaps();
  }

  _onFinishedEditing = () => {
    if (this.state.editingBinding) {
      const keymapPath = NylasEnv.keymaps.getUserKeymapPath();
      let keymaps = {};

      try {
        const exists = fs.existsSync(keymapPath);
        if (exists) {
          keymaps = JSON.parse(fs.readFileSync(keymapPath));
        }
      } catch (err) {
        console.error(err);
      }

      keymaps[this.props.command] = this.state.editingBinding;

      try {
        fs.writeFileSync(keymapPath, JSON.stringify(keymaps, null, 2));
      } catch (err) {
        NylasEnv.showErrorDialog(`Nylas was unable to modify your keymaps at ${keymapPath}. ${err.toString()}`);
      }
    }
    this.setState({editing: false, editingBinding: null});
    NylasEnv.keymaps.resumeAllKeymaps();
  }

  _onKey = (event) => {
    if (!this.state.editing) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    const [eventKey, eventMods] = keyAndModifiersForEvent(event);
    if (!eventKey || ['mod', 'meta', 'command', 'ctrl', 'alt', 'shift'].includes(eventKey)) {
      return;
    }

    let {keys, modifiers} = this.state;
    keys = keys.concat([eventKey]);
    modifiers = _.uniq(modifiers.concat(eventMods));

    let editingBinding = keys.join(' ');
    if (modifiers.length > 0) {
      editingBinding = [].concat(modifiers, keys).join('+');
      editingBinding = editingBinding.replace(/(meta|command|ctrl)/g, 'mod');
    }

    this.setState({keys, modifiers, editingBinding});
  }

  render() {
    const {editing, editingBinding} = this.state;
    const bindings = editingBinding ? [editingBinding] : this.props.bindings;

    let value = "None";
    if (bindings.length > 0) {
      value = _.uniq(bindings).map(this._renderKeystrokes);
    }

    let classnames = "shortcut";
    if (editing) {
      classnames += " editing";
    }
    return (
      <Flexbox
        className={classnames}
        tabIndex={-1}
        onKeyDown={this._onKey}
        onKeyPress={this._onKey}
        onFocus={this._onEdit}
        onBlur={this._onFinishedEditing}
      >
        <div className="col-left shortcut-name">
          {this.props.label}
        </div>
        <div className="col-right">
          <div className="values">{value}</div>
        </div>
      </Flexbox>
    );
  }
}
