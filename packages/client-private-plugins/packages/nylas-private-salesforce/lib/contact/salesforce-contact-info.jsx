import _ from 'underscore'
import React from 'react'

import {FocusedContentStore} from 'nylas-exports'

import SalesforceIcon from '../shared-components/salesforce-icon'
import * as dataHelpers from '../salesforce-object-helpers'
import SalesforceActions from '../salesforce-actions'
import OpenInSalesforceBtn from '../shared-components/open-in-salesforce-btn'
import SalesforceRelatedObjectCache from '../salesforce-related-object-cache'

class SalesforceContactInfo extends React.Component {
  static displayName = "SalesforceContactInfo";

  static containerStyles = {
    order: 97,
  }

  static propTypes = {
    contact: React.PropTypes.object.isRequired,
  }

  constructor(props) {
    super(props)
    this.state = { leads: [], contacts: [] }
  }

  componentDidMount() {
    this._fetchLead(this.props)
    this._disposable = SalesforceRelatedObjectCache.observeDirectlyRelatedSObjectsByEmail(this.props.contact.email).subscribe((sObjectsById = {}) => {
      const objsByType = _.groupBy(_.values(sObjectsById), "type");
      this.setState({
        leads: objsByType.Lead || [],
        contacts: objsByType.Contact || [],
      })
    })
  }

  componentWillReceiveProps(nextProps = {}) {
    this._fetchLead(nextProps)
  }

  componentWillUnmount() {
    this._disposable.dispose()
  }

  /**
   * We don't initial sync Leads because there are usually too many of
   * them (Millions). If a user inspects a contact, then we'll fetch leads
   * on demand. If we find a lead, it'll save to the Database which will
   * cause the SalesforceRelatedObjectCache to trigger for our observable.
   */
  _fetchLead(props) {
    const email = props.contact.email.toLowerCase().trim()
    return dataHelpers.loadBasicObjectsByField({
      objectType: "Lead",
      where: {Email: email},
    }).then(dataHelpers.upsertBasicObjects)
  }

  _requestNew(objectType, objectInitialData = {}) {
    const thread = FocusedContentStore.focused('thread')
    return SalesforceActions.openObjectForm({
      objectType: objectType,
      objectInitialData: objectInitialData,
      contextData: {
        nylasObjectId: thread.id,
        nylasObjectType: "Thread",
        focusedNylasContactData: {
          id: this.props.contact.id,
          name: this.props.contact.name,
          email: this.props.contact.email,
        },
      },
    })
  }

  _requestEdit(object) {
    const thread = FocusedContentStore.focused('thread')
    SalesforceActions.openObjectForm({
      objectId: object.id,
      objectType: object.type,
      objectInitialData: object,
      contextData: {
        nylasObjectId: thread.id,
        nylasObjectType: "Thread",
      },
    })
  }

  _renderObjectCreators() {
    const headers = []

    if (this.state.leads.length === 0) {
      headers.push(this._renderCreateObj("Lead"))
      if (this.state.contacts.length === 0) {
        headers.push(this._renderCreateObj("Contact"))
      }
    }

    if (headers.length === 0) { return false; }

    return <div className="related-sf-creators">{headers}</div>
  }

  _hasRelatedObjects() {
    return (this.state.leads.length > 0 || this.state.contacts.length > 0)
  }

  _renderRelatedObjects() {
    if (!this._hasRelatedObjects()) { return false; }
    return (
      <div className={`cell-container`}>
        {[this._renderRelatedSFObjects("Lead", this.state.leads),
          this._renderRelatedSFObjects("Contact", this.state.contacts)]}
      </div>
    )
  }

  _renderRelatedSFObjects(objectType, sfObjects = []) {
    const objDoms = []
    sfObjects.forEach((object) => {
      const reqEdit = _.debounce(() => this._requestEdit(object), 1000, true);
      const objDom = (
        <div
          key={object.id}
          onClick={reqEdit}
          title={`Edit ${objectType}`}
          className={`cell-item sf-profile ${objectType}-profile sf-related-object`}
        >
          <div className="main-cell-wrap">
            <SalesforceIcon objectType={objectType} />
            <span className="linkable-object-name">{object.name}</span>
            <OpenInSalesforceBtn objectId={object.id} />
          </div>
        </div>
      )
      objDoms.push(objDom)
      if (objectType === "Lead") {
        objDoms.push(this._renderConvertLead(object))
      }
    });
    return objDoms;
  }

  _renderCreateObj(objType) {
    const reqNew = () => this._requestNew(objType)
    return (
      <a
        key={`create-${objType}`}
        className={`create-${objType} create-sf-obj-link`}
        onClick={reqNew}
      >
        Create {objType} from {this.props.contact.firstName()}
      </a>
    )
  }

  _renderConvertLead(lead) {
    if (this.state.contacts.length > 0) { return false; }
    const convert = _.debounce(() =>
        this._requestNew("Contact", {
          Name: lead.name,
          Email: lead.identifier,
        }), 1000, true);
    return (
      <div
        className="cell-item action-item"
        title="Convert lead to contact"
        onClick={convert}
      >
        <SalesforceIcon objectType="lead_convert" className="round" />
        <span>Convert Lead to Contact</span>
      </div>
    )
  }

  render() {
    if (!this.props.contact) return false;
    if (this.props.contact.isMe()) return false;
    let h2 = false;
    if (this._hasRelatedObjects()) {
      h2 = <h2 className="sidebar-h2">Salesforce</h2>
    }
    return (
      <div className="salesforce-contact-info salesforce">
        {h2}
        {this._renderRelatedObjects()}
        {this._renderObjectCreators()}
      </div>
    )
  }
}

export default SalesforceContactInfo
