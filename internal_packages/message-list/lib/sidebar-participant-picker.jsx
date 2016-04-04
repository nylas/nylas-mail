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

  _renderSortedContacts() {
    return this.state.sortedContacts.map((contact) => {
      const selected = contact.email === (this.state.focusedContact || {}).email
      const key = contact.email + SPLIT_KEY + contact.name;

      return (
        <option selected={selected} value={key} key={key}>
          {contact.displayName({includeAccountLabel: true, forceAccountLabel: true})}
        </option>
      )
    });
  }

  _onSelectContact = (event) => {
    const [email, name] = event.target.value.split(SPLIT_KEY);
    const contact = _.filter(this.state.sortedContacts, (c) => {
      return c.name === name && c.email === email;
    })[0];
    return Actions.focusContact(contact);
  }

  render() {
    return (
      <div className="sidebar-participant-picker">
        <select tabIndex={-1} onChange={this._onSelectContact}>
        {this._renderSortedContacts()}
        </select>
      </div>
    )
  }


}
