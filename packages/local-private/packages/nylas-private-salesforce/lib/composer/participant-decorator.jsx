import React from 'react'
import {Rx, DatabaseStore} from 'nylas-exports'

import SalesforceIcon from '../shared-components/salesforce-icon'
import SalesforceObject from '../models/salesforce-object'

export default class ParticipantDecorator extends React.Component {

  static displayName = "ParticipantDecorator"
  static containerRequired = false

  static propTypes = {
    contact: React.PropTypes.object,
    collapsed: React.PropTypes.bool,
  }

  constructor(props) {
    super(props);
    this.state = { sfContacts: [] }
  }

  componentWillMount() {
    this._setupObserver(this.props)
  }

  componentWillReceiveProps(nextProps) {
    this._setupObserver(nextProps)
  }

  componentWillUnmount() {
    this._disposable.dispose();
  }

  _setupObserver(props) {
    if (this._disposable) this._disposable.dispose();
    const email = (props.contact.email || "").toLowerCase().trim()
    if (email.length === 0) return;
    const query = DatabaseStore.findAll(SalesforceObject)
    .where({type: "Contact", identifier: email})

    this._disposable = Rx.Observable.fromQuery(query)
    .subscribe((sfContacts = []) => {
      this.setState({sfContacts})
    })
  }

  render() {
    if (this.props.collapsed) return false;
    if (this.state.sfContacts.length === 0) return false
    return <SalesforceIcon objectType="Contact" />
  }
}
