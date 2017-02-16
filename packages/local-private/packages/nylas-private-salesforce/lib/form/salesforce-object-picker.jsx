import _ from 'underscore'
import React from 'react'
import titleize from 'underscore.string/titleize'
import {Actions, Utils, DatabaseStore} from 'nylas-exports'
import {FormItem, BoldedSearchResult, TokenizingTextField} from 'nylas-component-kit'

import SalesforceIcon from '../shared-components/salesforce-icon'
import SalesforceObject from '../models/salesforce-object'
import {loadBasicObject} from '../salesforce-object-helpers';
import SalesforceActions from '../salesforce-actions'
import PendingSalesforceObject from './pending-salesforce-object'

import * as formDataHelpers from './form-data-helpers'

const MAX_RESULTS = 100;

/*
This creates a selectable dropdown that lets you choose and create new
Salesforce objects.

It behaves like a standard formItem with a `value` prop and `onChange`. The value is always an array of SalesforceObject or PendingSalesforceObjects
*/
class SalesforceObjectPicker extends React.Component {
  static displayName = "SalesforceObjectPicker"

  static extendedPropTypes = {
    // Zero or more SalesforceObject's or PendingSalesforceObjects to turn
    // into `tokens` in the TokenizingTextField
    value: React.PropTypes.arrayOf(
      React.PropTypes.oneOfType([
        React.PropTypes.instanceOf(SalesforceObject),
        React.PropTypes.instanceOf(PendingSalesforceObject),
      ])
    ),

    /**
     * This is extra environment data about the form we're creating. It
     * includes data about the thread that we're creating this object in
     * context with, or with extra contact details used to help enrich the
     * form.
     */
    contextData: React.PropTypes.shape({
      /**
       * The unique ID of the form the picker is in. This is used when
       * creating "PendingSalesforceObject" that are linked to forms. When
       * those forms close, we can know what PendingSalesforceObjects to
       * remove.
       */
      formId: React.PropTypes.string,

      /**
       * The Salesforce object this form is about.
       * If the objectId is present, then we're editing an existing
       * object.
       */
      objectId: React.PropTypes.string,
      objectType: React.PropTypes.string,

      /**
       * The thread (or threads) that were selected when this object form
       * was requested. We use this to pre-fill contact form fields and
       * for analytics.
       */
      nylasObjectId: React.PropTypes.string,
      nylasObjectIds: React.PropTypes.array,
      nylasObjectType: React.PropTypes.string,

      /**
       * Used by SmartFields to pre-fill in data given the contact that
       * was focused when the object form was requested.
       */
      focusedNylasContactData: React.PropTypes.object,
    }),
  }

  static propTypes = Object.assign({},
      FormItem.propTypes, SalesforceObjectPicker.extendedPropTypes);

  static defaultProps = {
    value: [], // Does not protect if parent sets this to `null`
    onChange: () => {},
    contextData: {
      nylasObjectId: null,
      nylasObjectIds: [],
      nylasObjectType: null,
      focusedNylasContactData: null,
    },
  }

  componentWillMount() {
    this._usubs = [
      SalesforceActions.salesforceWindowClosing.listen(this._onSalesforceWindowClosing),
      SalesforceActions.syncbackSuccess.listen(this._onSyncbackSuccess),
    ]
  }

  componentWillUnmount() {
    for (const usub of this._usubs) { usub() }
  }

  focus() {
    this.refs.tokenizingTextField.focus()
  }

  _tokens() {
    return this.props.value || []
  }

  _onSyncbackSuccess = ({objectType, objectId, contextData = {}} = {}) => {
    return loadBasicObject(objectType, objectId)
    .then((sObject) => {
      this.props.onChange(this._tokens().map((o) => {
        if (o.id === contextData.formId) return sObject;
        return o;
      }));
    });
  }

  _onSalesforceWindowClosing = (args) => {
    if (args.closingDueToObjectSuccess) { return; }
    this.props.onChange(this._tokens().filter((o) => {
      return (o.id !== args.contextData.formId)
    }));
  }

  // Returns a salesforce object given the input
  _lookupSalesforceObject = (input = "", {clear} = {}) => {
    return new Promise((resolve, reject) => {
      let referenceTo = this.props.referenceTo;
      if (_.isString(this.props.referenceTo)) {
        referenceTo = [this.props.referenceTo]
      }
      if (clear) return resolve([])
      if (input.length > 0) {
        return DatabaseStore.findAll(SalesforceObject,
            {type: referenceTo})
        .where([SalesforceObject.attributes.name.like(input)])
        .then((objects = []) => {
          const re = Utils.wordSearchRegExp(input);
          const inputLower = input.toLowerCase()

          const sortedObjs = objects.sort((o1, o2) => {
            const o1Name = o1.name.toLowerCase()
            const o2Name = o2.name.toLowerCase()
            const i1 = re.test(o1.name) ? o1Name.search(inputLower) : 999
            const i2 = re.test(o2.name) ? o2Name.search(inputLower) : 999
            return i1 - i2
          })

          for (const referenceType of referenceTo) {
            /**
             * Note that we do NOT set an id for these objects. They will
             * be assigned random IDs that we'll use to set the formIDs of
             * the downstream forms that each of these represents.
             */
            const obj = new PendingSalesforceObject({
              type: referenceType,
              name: input,
            })
            sortedObjs.push(obj)
          }
          return resolve(sortedObjs.slice(0, MAX_RESULTS))
        })
        .catch(reject)
      }
      return resolve([])
    })
  }

  // An autocomplete suggestion item
  _renderObjectSuggestion = (obj, {inputValue} = {}) => {
    if (obj instanceof PendingSalesforceObject) {
      return (
        <div className="salesforce-suggestion new-object">
          <SalesforceIcon
            objectType={obj.type}
            className="round-create"
          />
          Create new {titleize(obj.type)} &ldquo;{obj.name}&rdquo;
        </div>
      )
    }
    return (
      <div className="salesforce-suggestion" title={obj.name}>
        <SalesforceIcon objectType={obj.type} />
        <BoldedSearchResult query={inputValue} value={obj.name} />
      </div>
    )
  }

  // Called with either a found object or a new value
  _onTokensAdd = (objs = []) => {
    objs.filter(o => o instanceof PendingSalesforceObject)
    .forEach(this._createNew)

    this.props.onChange(this._tokens().concat(objs))
    Actions.closePopover()
  }

  _onEditMotion = (object) => {
    if (!(object instanceof SalesforceObject)) return;
    SalesforceActions.openObjectForm({
      objectId: object.id,
      objectType: object.type,
      objectInitialData: object,
      contextData: this.props.contextData,
    })
  }

  _createNew = (pendingObj = {}) => {
    if ((pendingObj.name || "").trim().length === 0) return

    /**
     * When we create a PendingSalesforceObject, that means we want to
     * create a whole new form from that object. We use the
     * PendingSalesforceObject's id as the formId of the newly generated
     * form. The constructor of salesforce-object-form will detect the
     * formId in the passed-in contextData and initialize with that ID. By
     * letting us set the ID from here, we know what form to listen to
     * when the downstream form closes or saves.
     */
    const contextData = Object.assign({}, this.props.contextData, {
      formId: pendingObj.id,
    })

    SalesforceActions.openObjectForm({
      objectType: pendingObj.type,
      contextData: contextData,
      objectInitialData: this._initialDataForNewObject(pendingObj),
    });
  }

  /**
   * When you're going to create a new object there is a lot of
   * information we can give you a head start on that new object.
   *
   * First when you create a new object through the Salesforce Object
   * Picker, we have the name you just typed.
   *
   * Second, the GeneratedForm also passes to each formItem (including
   * this one) the currentFormValues. We pass those along as initial data.
   * If we're editing a Contact and we create a new Opportunity, the
   * Opportunity will want the same AccountId as the Contact's AccountID.
   * By passing along the currentFormValues, we can pre-fill the
   * Opportunity with what we have already.
   *
   * Third, we create a backRefObj to the current form you have open. If
   * we're creating a brand new Contact, and also start creating an
   * Account, the Account form can have a back reference to the in-flight
   * Contact we're creating or the existing Contact we already have.
   *
   * Fourth, we pass along all additional contextData. That contextData
   * includes the Nylas Thread & Contact in scope when we create this
   * object. Our SmartFields adapter will use that information to query
   * Clearbit and other data sources to fill in as much as possible. See
   * SmartFields for a variety of other techniques we use to pre-fill the
   * form.
   */
  _initialDataForNewObject = (pendingObj = {}) => {
    const rawForm = this.props.currentFormValues || {}
    const initialData = {}
    for (const name of Object.keys(rawForm)) {
      initialData[name] = formDataHelpers.serializeRawFormValue(rawForm[name])
    }

    initialData.Name = pendingObj.name;

    const selfType = this.props.contextData.objectType;

    let backRef = null
    if (this.props.contextData.objectId) {
      /**
       * For existing objects, we just need the ID of the object. It will
       * be re-inflated when the downstream form loads.
       */
      backRef = this.props.contextData.objectId
    } else {
      /**
       * The id needs to be the formId of the object that created us.
       * When we send this initialData to a new form,
       * SmartFields._resolveInitialRefs will unpack the
       * PendingSalesforceObject JSON and create the appropriate
       * PendingSalesforceObject with the given ID.
       */
      backRef = new PendingSalesforceObject({
        id: this.props.contextData.formId,
        type: selfType,
      }).toJSON()
    }

    let key = null
    if (this.props.referenceType === "hasManyThrough") {
      // Back-reference will be a hasManyThrough since this is a
      // hasManyThrough
      key = `${selfType}Ids`
    } else if (this.props.referenceType === "hasMany") {
      // Back-reference will be a belongsTo since this is a hasMany
      key = `${selfType}Id`
    } else {
      // Back-reference will be a hasMany since this is a belongsTo
      key = `${selfType}Ids`
    }
    if (!initialData[key]) initialData[key] = [];
    initialData[key].push(backRef);
    return initialData
  }

  // The found token object
  _renderFoundObject = (props) => {
    if (props.token instanceof SalesforceObject) {
      return (
        <div className="salesforce-object">
          <SalesforceIcon objectType={props.token.type} />
          {props.token.name}
        </div>
      )
    } else if (props.token instanceof PendingSalesforceObject) {
      return (
        <div className="salesforce-object token-pending">
          <SalesforceIcon objectType={props.token.type} pending />
          Creating {props.token.type}…
        </div>
      )
    }
    return false
  }

  _onTokensRemoved = (objs = []) => {
    const toRemoveIds = objs.map(o => o.id);
    const val = this._tokens().filter(o => !toRemoveIds.includes(o.id));
    this.props.onChange(val)
  }

  render() {
    const objId = (obj) => obj.id
    return (
      <div className="salesforce-object-picker">
        <TokenizingTextField
          ref="tokenizingTextField"
          onAdd={this._onTokensAdd}
          tokens={this._tokens()}
          onRemove={this._onTokensRemoved}
          tokenKey={objId}
          disabled={this.props.disabled}
          tabIndex={this.props.tabIndex}
          maxTokens={this.props.multiple ? null : 1}
          placeholder={this.props.placeholder}
          defaultValue={this.props.defaultValue}
          onEditMotion={this._onEditMotion}
          tokenRenderer={this._renderFoundObject}
          completionNode={this._renderObjectSuggestion}
          onRequestCompletions={this._lookupSalesforceObject}
        />
      </div>
    )
  }
}

export default SalesforceObjectPicker
