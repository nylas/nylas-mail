import _ from 'underscore'
import _str from 'underscore.string'
import React from 'react'
import moment from 'moment'
import ReactDOM from 'react-dom'
import {Utils, DatabaseStore, AccountStore, FocusedContactsStore} from 'nylas-exports'

import SalesforceIcon from '../shared-components/salesforce-icon'
import SalesforceObject from '../models/salesforce-object'
import SyncThreadToggle from './sync-thread-toggle'
import SalesforceActions from '../salesforce-actions'
import OpenInSalesforceBtn from '../shared-components/open-in-salesforce-btn'

import * as dataHelpers from '../salesforce-object-helpers'
import * as relatedHelpers from '../related-object-helpers'
import {CORE_RELATEABLE_OBJECT_TYPES} from '../salesforce-constants'

class RelatedObjectsForThread extends React.Component {
  static displayName = "RelatedObjectsForThread"

  static containerStyles = {
    order: 2,
    flexShrink: 0,
  }

  static propTypes = {
    thread: React.PropTypes.object,
  }

  constructor(props) {
    super(props);
    this.state = this._initialState();
  }

  componentWillMount() {
    this._setupDataSource(this.props);
    this._usub = FocusedContactsStore.listen(this._onContactChange)
  }

  componentWillReceiveProps(nextProps) {
    this._setupDataSource(nextProps)
  }

  componentWillUnmount() {
    if (this.disposable && this.disposable.dispose) {
      this.disposable.dispose()
    }
    this._usub()
  }

  _initialState() {
    return {
      expanded: false,
      subObjects: {},
      relatedObjects: [],
      focusedContact: FocusedContactsStore.focusedContact(),
      focusedContacts: FocusedContactsStore.sortedContacts(),
    }
  }

  _onContactChange = () => {
    this.setState({
      focusedContact: FocusedContactsStore.focusedContact(),
      focusedContacts: FocusedContactsStore.sortedContacts(),
    })
  }

  _setupDataSource(props) {
    if (this.disposable && this.disposable.dispose) {
      this.disposable.dispose()
    }
    this.setState(this._initialState())
    this.disposable = relatedHelpers.observeRelatedSObjectsForThread(props.thread).subscribe((relatedObjects) => {
      return Promise.map(relatedObjects, (relatedObj) => {
        return dataHelpers.loadFullObject({
          objectId: relatedObj.id,
          objectType: relatedObj.type,
        })
      }).then((fullObjs) => {
        const objs = fullObjs.filter(obj =>
            CORE_RELATEABLE_OBJECT_TYPES.includes(obj.type))
        this.setState({relatedObjects: objs})
        return Promise.each(this._mainObjects(objs), this._loadSubObjects)
      })
    })
  }

  // TODO: Do in more extensible way when SalesforceConfig Main Object
  // types come into play
  // TODO: Make a subObject observer;
  _loadSubObjects = (mainObj) => {
    if (mainObj.type === "Opportunity") {
      return DatabaseStore.findAll(SalesforceObject,
        {type: "OpportunityContactRole", relatedToId: mainObj.id})
      .then((roles = []) => {
        if (roles.length === 0) return []
        return DatabaseStore.findAll(SalesforceObject, {
          type: "Contact", id: roles.map(r => r.identifier),
        })
      }).then((contacts = []) => {
        let p = Promise.resolve([]);
        if (mainObj.relatedToId) {
          p = DatabaseStore.findAll(SalesforceObject, {type: "Account", id: mainObj.relatedToId})
        }
        return p.then((accounts = []) => {
          const subObjs = Utils.deepClone(this.state.subObjects);
          subObjs[mainObj.id] = accounts.concat(contacts);
          this.setState({subObjects: subObjs})
        })
      })
    } else if (mainObj.type === "Account") {
      return DatabaseStore.findAll(SalesforceObject,
        {type: "Contact", relatedToId: mainObj.id})
      .then((objs = []) => {
        const subObjs = Utils.deepClone(this.state.subObjects);
        subObjs[mainObj.id] = objs;
        this.setState({subObjects: subObjs})
      })
    }
    return Promise.resolve()
  }

  _extraInfoForObj(obj) {
    if (obj.type === "Opportunity" && obj.rawData) {
      const opp = obj.rawData
      const info = []
      if (opp.Amount) {
        const amnt = opp.Amount.toFixed(0).replace(/(\d)(?=(\d\d\d)+(?!\d))/g, "$1,")
        info.push(`$${amnt}`)
      }
      if (opp.StageName) {
        info.push(`${opp.StageName}`)
      }
      if (opp.Probability) {
        info.push(`${opp.Probability}%`)
      }
      if (opp.CloseDate) {
        info.push(`Close ${opp.CloseDate}`)
      }
      if (opp.LastActivityDate) {
        info.push(`Last activity: ${moment(opp.LastActivityDate).fromNow()}`)
      }
      return info.join(" • ")
    } else if (obj.type === "Contact") {
      return obj.identifier || ""
    }
    return ""
  }

  _requestEdit(object) {
    let focusedNylasContactData = null;
    if (this.state.focusedContact) {
      focusedNylasContactData = {
        id: this.state.focusedContact.id,
        name: this.state.focusedContact.name,
        email: this.state.focusedContact.email,
      }
    }
    SalesforceActions.openObjectForm({
      objectId: object.id,
      objectType: object.type,
      objectInitialData: object,
      contextData: {
        nylasObjectId: this.props.thread.id,
        nylasObjectType: "Thread",
        focusedNylasContactData: focusedNylasContactData,
      },
    })
  }

  _createNewContact(participant, mainObj) {
    const objectInitialData = {}
    if (mainObj.type === "Opportunity") {
      objectInitialData.OpportunityIds = [mainObj.id]
    }
    const subObjs = this._subObjects(mainObj);
    const account = subObjs.filter(o => o.type === "Account")[0]
    if (account) {
      objectInitialData.AccountId = account.id;
    }
    SalesforceActions.openObjectForm({
      objectType: "Contact",
      objectInitialData: objectInitialData,
      contextData: {
        nylasObjectId: this.props.thread.id,
        nylasObjectType: "Thread",
        focusedNylasContactData: {
          name: participant.name,
          email: participant.email,
        },
      },
    })
  }

  _editObj = (obj) => {
    const reqEdit = _.debounce(() => this._requestEdit(obj), 1000, true);
    return (event) => {
      const wrap = ReactDOM.findDOMNode(this.refs.relObjects);
      const toggles = Array.from(wrap.querySelectorAll(".thread-toggles"));
      for (const toggle of toggles) {
        if (toggle.contains(event.target)) {
          return
        }
      }
      reqEdit()
    }
  }

  _humanize(type) {
    return _str.titleize(_str.humanize(type))
  }

  _renderMainObject = (obj) => {
    if (!obj) return null
    return (
      <div
        className="cell-item sf-related-object large-cell"
        key={obj.id}
      >
        <div
          className="main-cell-wrap"
          title={`Edit ${this._humanize(obj.type)}`}
          onClick={this._editObj(obj)}
        >
          <SalesforceIcon objectType={obj.type} />

          <span className="synced-wrap">
            <span className={`linkable-object-name ${obj.type}`}>
              {obj.name}
            </span>
            <span className="linkable-object-details">
              {this._extraInfoForObj(obj)}
            </span>
          </span>

          <span ref="syncThreadToggle" className="thread-toggles">
            <SyncThreadToggle
              thread={this.props.thread}
              sObjectId={obj.id}
              sObjectType={obj.type}
            />
          </span>

          <OpenInSalesforceBtn objectId={obj.id} size="large" />
        </div>

        {this._renderSubObjects(obj)}
      </div>
    )
  }

  _renderSubObjects(obj) {
    const PADDING = 5 + 5 + 1; // paddings + border-bottom
    const SUB_OBJ_HEIGHT = 26;
    const NUM_TO_SHOW = 3;

    const subObjs = this._subObjects(obj);
    if (subObjs.length === 0) return false;
    const participants = this._remainingParticipants(subObjs);

    let numParticipants = participants.length;
    if (this.state.focusedContacts.length === 0) {
      // This means we're still loading participants. Guess box height
      // from thread participants so we don't reflow the message list of
      // the thread for users.
      numParticipants = this.props.thread.participants.length
    }

    const numSubObjs = subObjs.length + numParticipants;
    const numToShow = this.state.expanded ? numSubObjs : Math.min(numSubObjs, NUM_TO_SHOW);

    const onToggle = () => this.setState({expanded: !this.state.expanded})
    const hasToggle = (numSubObjs > NUM_TO_SHOW)
    const msg = this.state.expanded ? "Collapse" : "Show more"
    const toggle = (
      <div className="toggle" key={`toggle-${obj.id}`} onClick={onToggle}>{msg}</div>
    )

    // Since you can't animate to height: auto
    let height = numToShow * SUB_OBJ_HEIGHT + PADDING;

    // Otherwise the base height overflows
    if (hasToggle) height -= 2;

    if (this.state.expanded) {
      height = numToShow * SUB_OBJ_HEIGHT + PADDING;
    }
    return [
      <div key={`subItemsWrap-${obj.id}`} className="sub-items-wrap" style={{height}}>
        {subObjs.map(this._renderSubObject)}
        {participants.map(this._renderSuggestedContact(obj))}
      </div>,
      (hasToggle ? toggle : false),
    ]
  }

  _remainingParticipants = (subObjs) => {
    const emails = new Set(subObjs.map(o => (o.identifier || "")))
    return this.state.focusedContacts.filter(p =>
      !emails.has(p.email) && !AccountStore.accountForEmail(p.email)
    )
  }

  _renderSuggestedContact = (mainObj) => {
    return (participant) => {
      const reqCreate = _.debounce(() =>
        this._createNewContact(participant, mainObj), 1000, true
      );
      return (
        <div
          className={`sub-item`}
          key={`${participant.email}-${participant.name}`}
          title={`Create Contact for ${participant.email}`}
          onClick={reqCreate}
        >
          <SalesforceIcon objectType="Contact" className="round-create" />
          <div className="synced-wrap">
            Add:&nbsp;
            <span className="linkable-object-name">
              {participant.fullName()}
            </span>
            <span className="linkable-object-details">
              {participant.email}
            </span>
          </div>
        </div>
      )
    }
  }

  _renderSubObject = (subObj) => {
    return (
      <div
        className={`sub-item ${subObj.type}`}
        key={`subItem-${subObj.id}`}
        title={`Edit ${this._humanize(subObj.type)}`}
        onClick={this._editObj(subObj)}
      >
        <SalesforceIcon objectType={subObj.type} />
        <div className="synced-wrap">
          <span className="linkable-object-name">{subObj.name}</span>
          <span className="linkable-object-details">
            {this._extraInfoForObj(subObj)}
          </span>
        </div>
        <OpenInSalesforceBtn objectId={subObj.id} />
      </div>
    )
  }

  // _renderNewPrompt() {
  //   const forWhom = this.state.focusedContact;
  //   let company = null;
  //   let text = ""
  //   if (forWhom) {
  //     company = SmartFields.getFieldFromClearbit(forWhom, "Contact", "Company");
  //     text = `for ${company || forWhom.firstName()}`;
  //   }
  //   return (
  //     <div className="cell-container inline">
  //       <div className="cell-item new-item">
  //         <SalesforceIcon objectType="Opportunity" className="round-create" />
  //         <span>Create Opportunity {text}</span>
  //       </div>
  //     </div>
  //   )
  // }

  // TODO: Replace with SalesforceConfig
  _mainObjects = (objs = []) => {
    const opps = objs.filter(o => o.type === "Opportunity");
    if (opps.length > 0) return opps;
    const accounts = objs.filter(o => o.type === "Account");
    if (accounts.length > 0) return accounts;
    return [];
  }

  _subObjects(obj) {
    return this.state.subObjects[obj.id] || []
  }

  _renderMainObjects() {
    const mainObjects = this._mainObjects(this.state.relatedObjects);
    if (mainObjects.length > 0) {
      return (
        <div className="cell-container">
          {mainObjects.map(this._renderMainObject)}
        </div>
      )
    }
    return false;
  }

  render() {
    if (!this.props.thread) return false
    return (
      <div className="salesforce related-objects-wrap" ref="relObjects">
        {this._renderMainObjects()}
      </div>
    )
  }
}

export default RelatedObjectsForThread
