/** @babel */

import _ from 'underscore'
import React from 'react';
import {Actions, FocusedContactsStore} from 'nylas-exports'

const SPLIT_KEY = "---splitvalue---"

export default class SidebarParticipantPicker extends React.Component {
  static displayName = 'SidebarParticipantPicker';

  constructor(props) {
    super(props);
    this.props = props;
    this._onSelectContact = this._onSelectContact.bind(this);
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

  static containerStyles = {
    order: 0,
    flexShrink: 0,
  };

  _getStateFromStores() {
    return {
      sortedContacts: FocusedContactsStore.sortedContacts(),
      focusedContact: FocusedContactsStore.focusedContact(),
    };
  }

  _getKeyForContact(contact) {
    if (!contact) {
      return null
    }
    return contact.email + SPLIT_KEY + contact.name
  }

  _onSelectContact = (event) => {
    const [email, name] = event.target.value.split(SPLIT_KEY);
    const contact = _.filter(this.state.sortedContacts, (c) => {
      return c.name === name && c.email === email;
    })[0];
    return Actions.focusContact(contact);
  }

  _renderSortedContacts() {
    return this.state.sortedContacts.map((contact) => {
      const key = this._getKeyForContact(contact)

      return (
        <option value={key} key={key}>
          {contact.displayName({includeAccountLabel: true, forceAccountLabel: true})}
        </option>
      )
    });
  }

  render() {
    const {focusedContact} = this.state
    const value = this._getKeyForContact(focusedContact)
    return (
      <div className="sidebar-participant-picker">
        <select tabIndex={-1} value={value} onChange={this._onSelectContact}>
        {this._renderSortedContacts()}
        </select>
      </div>
    )
  }


}
