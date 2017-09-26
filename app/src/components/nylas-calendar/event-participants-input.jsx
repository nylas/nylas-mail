import _ from 'underscore';
import { remote, clipboard } from 'electron';
import { React, PropTypes, Utils, Contact, ContactStore, RegExpUtils } from 'mailspring-exports';
import { TokenizingTextField, Menu, InjectedComponentSet } from 'mailspring-component-kit';

const TokenRenderer = props => {
  const { email, name } = props.token;
  let chipText = email;
  if (name && name.length > 0 && name !== email) {
    chipText = name;
  }
  return (
    <div className="participant">
      <InjectedComponentSet
        matching={{ role: 'Composer:RecipientChip' }}
        exposedProps={{ contact: props.token }}
        direction="column"
        inline
      />
      <span className="participant-primary">{chipText}</span>
    </div>
  );
};

TokenRenderer.propTypes = {
  token: PropTypes.object,
};

export default class EventParticipantsInput extends React.Component {
  static displayName = 'EventParticipantsInput';

  static propTypes = {
    participants: PropTypes.array.isRequired,
    change: PropTypes.func.isRequired,
    className: PropTypes.string,
    onEmptied: PropTypes.func,
    onFocus: PropTypes.func,
  };

  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.isEqualReact(nextProps, this.props) || !Utils.isEqualReact(nextState, this.state);
  }

  // Public. Can be called by any component that has a ref to this one to
  // focus the input field.
  focus = () => {
    this.refs.textField.focus();
  };

  _completionNode = p => {
    return <Menu.NameEmailItem name={p.name} email={p.email} />;
  };

  _tokensForString = (string, options = {}) => {
    // If the input is a string, parse out email addresses and build
    // an array of contact objects. For each email address wrapped in
    // parentheses, look for a preceding name, if one exists.
    if (string.length === 0) {
      return Promise.resolve([]);
    }

    return ContactStore.parseContactsInString(string, options).then(contacts => {
      if (contacts.length > 0) {
        return Promise.resolve(contacts);
      }
      // If no contacts are returned, treat the entire string as a single
      // (malformed) contact object.
      return [new Contact({ email: string, name: null })];
    });
  };

  _remove = values => {
    const updates = _.reject(
      this.props.participants,
      p => values.includes(p.email) || values.map(o => o.email).includes(p.email)
    );
    this.props.change(updates);
  };

  _edit = (token, replacementString) => {
    const tokenIndex = this.props.participants.indexOf(token);

    this._tokensForString(replacementString).then(replacements => {
      const updates = this.props.participants.slice(0);
      updates.splice(tokenIndex, 1, ...replacements);
      this.props.change(updates);
    });
  };

  _add = (values, options = {}) => {
    // If the input is a string, parse out email addresses and build
    // an array of contact objects. For each email address wrapped in
    // parentheses, look for a preceding name, if one exists.
    let tokensPromise = null;
    if (typeof values === 'string') {
      tokensPromise = this._tokensForString(values, options);
    } else {
      tokensPromise = Promise.resolve(values);
    }

    tokensPromise.then(tokens => {
      // Safety check: remove anything from the incoming tokens that isn't
      // a Contact. We should never receive anything else in the tokens array.
      const contactTokens = tokens.filter(value => value instanceof Contact);
      let updates = this.props.participants.slice(0);

      for (const token of contactTokens) {
        // add the participant to field. _.union ensures that the token will
        // only appear once, in case it already exists in the participants.
        updates = _.union(updates, [token]);
      }

      this.props.change(updates);
    });
  };

  _onShowContextMenu = participant => {
    // Warning: Menu is already initialized as Menu.cjsx!
    const MenuClass = remote.Menu;
    const MenuItem = remote.MenuItem;

    const menu = new MenuClass();
    menu.append(
      new MenuItem({
        label: `Copy ${participant.email}`,
        click: () => clipboard.writeText(participant.email),
      })
    );
    menu.append(
      new MenuItem({
        type: 'separator',
      })
    );
    menu.append(
      new MenuItem({
        label: 'Remove',
        click: () => this._remove([participant]),
      })
    );
    menu.popup(remote.getCurrentWindow());
  };

  _onInputTrySubmit = (inputValue, completions = [], selectedItem) => {
    if (RegExpUtils.emailRegex().test(inputValue)) {
      return inputValue; // no token default to raw value.
    }
    return selectedItem || completions[0]; // first completion if any
  };

  _shouldBreakOnKeydown = event => {
    const val = event.target.value.trim();
    if (RegExpUtils.emailRegex().test(val) && event.key === ' ') {
      return true;
    }
    return [',', ';'].includes(event.key);
  };

  render() {
    return (
      <TokenizingTextField
        className={this.props.className}
        ref="textField"
        tokens={this.props.participants}
        tokenKey={p => p.email}
        tokenIsValid={p => ContactStore.isValidContact(p)}
        tokenRenderer={TokenRenderer}
        onRequestCompletions={input => ContactStore.searchContacts(input)}
        shouldBreakOnKeydown={this._shouldBreakOnKeydown}
        onInputTrySubmit={this._onInputTrySubmit}
        completionNode={this._completionNode}
        onAdd={this._add}
        onRemove={this._remove}
        onEdit={this._edit}
        onEmptied={this.props.onEmptied}
        onFocus={this.props.onFocus}
        onTokenAction={this._onShowContextMenu}
      />
    );
  }
}
