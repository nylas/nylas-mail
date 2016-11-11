import React from 'react';
import _ from 'underscore';

import {remote, clipboard} from 'electron';
import {Utils, Contact, ContactStore, RegExpUtils} from 'nylas-exports';
import {TokenizingTextField, Menu, InjectedComponent, InjectedComponentSet} from 'nylas-component-kit';

const TokenRenderer = (props) => {
  const {email, name} = props.token
  let chipText = email;
  if (name && (name.length > 0) && (name !== email)) {
    chipText = name;
  }
  return (
    <div className="participant">
      <InjectedComponentSet
        matching={{role: "Composer:RecipientChip"}}
        exposedProps={{contact: props.token, collapsed: false}}
        direction="row"
        inline
      />
      <span className="participant-primary">{chipText}</span>
    </div>
  );
};

TokenRenderer.propTypes = {
  token: React.PropTypes.object,
};

export default class ParticipantsTextField extends React.Component {
  static displayName = 'ParticipantsTextField';

  static propTypes = {
    // The name of the field, used for both display purposes and also
    // to modify the `participants` provided.
    field: React.PropTypes.string,

    // An object containing arrays of participants. Typically, this is
    // {to: [], cc: [], bcc: []}. Each ParticipantsTextField needs all of
    // the values, because adding an element to one field may remove it
    // from another.
    participants: React.PropTypes.object.isRequired,

    // The function to call with an updated `participants` object when
    // changes are made.
    change: React.PropTypes.func.isRequired,

    className: React.PropTypes.string,

    onEmptied: React.PropTypes.func,

    onFocus: React.PropTypes.func,

    draft: React.PropTypes.object,

    session: React.PropTypes.object,
  }

  static defaultProps = {
    visible: true,
  }

  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.isEqualReact(nextProps, this.props) || !Utils.isEqualReact(nextState, this.state);
  }

  // Public. Can be called by any component that has a ref to this one to
  // focus the input field.
  focus = () => {
    this.refs.textField.focus();
  }

  _completionNode = (p) => {
    const CustomComponent = p.customComponent
    if (CustomComponent) return (<CustomComponent token={p} />)
    return (
      <Menu.NameEmailItem name={p.name} email={p.email} key={p.id} />
    );
  }

  _tokensForString = (string, options = {}) => {
    // If the input is a string, parse out email addresses and build
    // an array of contact objects. For each email address wrapped in
    // parentheses, look for a preceding name, if one exists.
    if (string.length === 0) {
      return Promise.resolve([]);
    }

    return ContactStore.parseContactsInString(string, options).then((contacts) => {
      if (contacts.length > 0) {
        return Promise.resolve(contacts);
      }
      // If no contacts are returned, treat the entire string as a single
      // (malformed) contact object.
      return [new Contact({email: string, name: null})];
    });
  }

  _remove = (values) => {
    const field = this.props.field;
    const updates = {};
    updates[field] = _.reject(this.props.participants[field], (p) =>
      values.includes(p.email) || values.map(o => o.email).includes(p.email)
    );
    this.props.change(updates);
  }

  _edit = (token, replacementString) => {
    const field = this.props.field;
    const tokenIndex = this.props.participants[field].indexOf(token);

    this._tokensForString(replacementString).then((replacements) => {
      const updates = {};
      updates[field] = [].concat(this.props.participants[field]);
      updates[field].splice(tokenIndex, 1, ...replacements);
      this.props.change(updates);
    });
  }

  _add = (values, options = {}) => {
    // It's important we return here (as opposed to ignoring the
    // `this.props.change` callback) because this method is asynchronous.

    // The `tokensPromise` may be formed with an empty draft, but resolved
    // after a draft was prepared. This would cause the bad data to be
    // propagated.

    // If the input is a string, parse out email addresses and build
    // an array of contact objects. For each email address wrapped in
    // parentheses, look for a preceding name, if one exists.
    let tokensPromise = null;
    if (_.isString(values)) {
      tokensPromise = this._tokensForString(values, options);
    } else {
      tokensPromise = Promise.resolve(values);
    }

    tokensPromise.then((tokens) => {
      // Safety check: remove anything from the incoming tokens that isn't
      // a Contact. We should never receive anything else in the tokens array.
      const contactTokens = tokens.filter(value => value instanceof Contact);

      const updates = {}
      for (const field of Object.keys(this.props.participants)) {
        updates[field] = [].concat(this.props.participants[field]);
      }

      for (const token of contactTokens) {
        // first remove the participant from all the fields. This ensures
        // that drag and drop isn't "drag and copy." and you can't have the
        // same recipient in multiple places.
        for (const field of Object.keys(this.props.participants)) {
          updates[field] = _.reject(updates[field], p => p.email === token.email)
        }

        // add the participant to field
        updates[this.props.field] = _.union(updates[this.props.field], [token]);
      }

      this.props.change(updates);
    });

    return "";
  }

  _onShowContextMenu = (participant) => {
    // Warning: Menu is already initialized as Menu.cjsx!
    const MenuClass = remote.Menu;
    const MenuItem = remote.MenuItem;

    const menu = new MenuClass();
    menu.append(new MenuItem({
      label: `Copy ${participant.email}`,
      click: () => clipboard.writeText(participant.email),
    }))
    menu.append(new MenuItem({
      type: 'separator',
    }))
    menu.append(new MenuItem({
      label: 'Remove',
      click: () => this._remove([participant]),
    }))
    menu.popup(remote.getCurrentWindow());
  }

  _onInputTrySubmit = (inputValue, completions = [], selectedItem) => {
    if (RegExpUtils.emailRegex().test(inputValue)) {
      return inputValue // no token default to raw value.
    }
    return selectedItem || completions[0] // first completion if any
  }

  _shouldBreakOnKeydown = (event) => {
    const val = event.target.value.trim();
    if (RegExpUtils.emailRegex().test(val) && event.key === " ") {
      return true
    }
    return [",", ";"].includes(event.key)
  }

  render() {
    const classSet = {
      [this.props.field]: true,
    };
    const draftId = this.props.draft ? this.props.draft.clientId : null
    // TODO Ahh now that this component is part of the component kit this
    // injected region feels out of place
    return (
      <div className={this.props.className}>
        <InjectedComponent
          ref="textField"
          matching={{role: 'Composer:ParticipantsTextField'}}
          fallback={TokenizingTextField}
          requiredMethods={['focus']}
          exposedProps={{
            tokens: this.props.participants[this.props.field],
            tokenKey: (p) => p.email,
            tokenIsValid: (p) => ContactStore.isValidContact(p),
            tokenRenderer: TokenRenderer,
            onRequestCompletions: (input) => ContactStore.searchContacts(input),
            shouldBreakOnKeydown: this._shouldBreakOnKeydown,
            onInputTrySubmit: this._onInputTrySubmit,
            completionNode: this._completionNode,
            onAdd: this._add,
            onRemove: this._remove,
            onEdit: this._edit,
            onEmptied: this.props.onEmptied,
            onFocus: this.props.onFocus,
            onTokenAction: this._onShowContextMenu,
            menuClassSet: classSet,
            menuPrompt: this.props.field,
            field: this.props.field,
            draft: this.props.draft,
            draftClientId: draftId,
            session: this.props.session,
          }}
        />
      </div>
    );
  }
}
