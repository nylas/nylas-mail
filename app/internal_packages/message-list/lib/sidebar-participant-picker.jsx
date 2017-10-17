import React from 'react';
import { Actions, FocusedContactsStore } from 'mailspring-exports';

const SPLIT_KEY = '---splitvalue---';

export default class SidebarParticipantPicker extends React.Component {
  static displayName = 'SidebarParticipantPicker';

  static containerStyles = {
    order: 0,
    flexShrink: 0,
  };

  constructor(props) {
    super(props);
    this.state = this._getStateFromStores();
  }

  componentDidMount() {
    this._usub = FocusedContactsStore.listen(() => {
      return this.setState(this._getStateFromStores());
    });
  }

  componentWillUnmount() {
    this._usub();
  }

  _getStateFromStores() {
    return {
      sortedContacts: FocusedContactsStore.sortedContacts(),
      focusedContact: FocusedContactsStore.focusedContact(),
    };
  }

  _getKeyForContact(contact) {
    if (!contact) {
      return null;
    }
    return contact.email + SPLIT_KEY + contact.name;
  }

  _onSelectContact = event => {
    const { sortedContacts } = this.state;
    const [email, name] = event.target.value.split(SPLIT_KEY);
    const contact = sortedContacts.find(c => (c.name === name || typeof c.name == "undefined" ) && c.email === email);
    return Actions.focusContact(contact);
  };

  _renderSortedContacts() {
    return this.state.sortedContacts.map(contact => {
      const key = this._getKeyForContact(contact);

      return (
        <option value={key} key={key}>
          {contact.displayName({ includeAccountLabel: true, forceAccountLabel: true })}
        </option>
      );
    });
  }

  render() {
    const { sortedContacts, focusedContact } = this.state;
    const value = this._getKeyForContact(focusedContact);
    if (sortedContacts.length === 0 || !value) {
      return false;
    }
    return (
      <div className="sidebar-participant-picker">
        <select tabIndex={-1} value={value} onChange={this._onSelectContact}>
          {this._renderSortedContacts()}
        </select>
      </div>
    );
  }
}
