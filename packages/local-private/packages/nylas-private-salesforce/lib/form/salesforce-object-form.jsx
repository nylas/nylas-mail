import React from 'react'
import _ from 'underscore'
import _str from 'underscore.string'
import {Utils, Actions} from 'nylas-exports'
import {Spinner, GeneratedForm} from 'nylas-component-kit'

import SmartFields from './smart-fields';
import RemoveControls from './remove-controls'
import * as dataHelpers from '../salesforce-object-helpers'
import SalesforceActions from '../salesforce-actions'
import * as formDataHelpers from './form-data-helpers'
import SalesforceObjectPicker from './salesforce-object-picker'
import FetchEmptySchemaForType from './fetch-empty-schema-for-type'
import SyncbackSalesforceObjectTask from '../tasks/syncback-salesforce-object-task';
import GeneratedFormToSalesforceAdapter from './generated-form-to-salesforce-adapter';

class SalesforceObjectForm extends React.Component {
  static displayName = "SalesforceObjectForm"
  static containerRequired = false

  static propTypes = {
    /**
     * The Salesforce Object ID. This is only given if we're editing an
     * existing object. If it's blank that means we're creating a new
     * object.
     */
    objectId: React.PropTypes.string,

    // The type of Salesforce Object
    objectType: React.PropTypes.string.isRequired,

    /**
     * When the object form is created, it's passed in contextData. We use
     * this data to help us intelligently fill out the form. We also pass
     * the contextData onto the form so any downstream objects get created
     * accordingly.
     */
    contextData: SalesforceObjectPicker.propTypes.contextData,

    // Any initial data we get passed when creating this object.
    objectInitialData: React.PropTypes.object,
  }

  static defaultProps = {
    contextData: {},
    objectInitialData: {},
  }

  constructor(props) {
    super(props);
    this.formId = props.contextData.formId || Utils.generateTempId()
    this.state = {
      formData: null,
      submitting: false,
      formLoadingErrorMsg: null,
    }
  }

  componentWillMount() {
    this._usubs = [
      SalesforceActions.deleteSuccess.listen(this._onDeleteSuccess),
      SalesforceActions.syncbackFailed.listen(this._onSyncbackFailed),
      SalesforceActions.syncbackSuccess.listen(this._onSyncbackSuccess),
    ]

    NylasEnv.onBeforeUnload(this._onBeforeUnload);

    this._initializeNewFormData().then(formData => {
      this.setState({formData})
    })
  }

  componentWillUnmount() {
    for (const usub of this._usubs) { usub() }
    return NylasEnv.removeUnloadCallback(this._onBeforeUnload);
  }

  _initializeNewFormData() {
    return FetchEmptySchemaForType.run(this.props.objectType)
    .then((emptySchema) => {
      const initialSchema = this._addContextData(emptySchema)
      return Promise.props({
        initialSchema: initialSchema,
        objectInitialData: this._initialData(),
      }).then(SmartFields.fillForm)
    })
    .catch(this._handleFormLoadingErrors);
  }

  _addContextData(emptySchema) {
    return Object.assign({}, emptySchema, {
      formType: this.props.objectId ? "update" : "new",
      contextData: Object.assign({}, this.props.contextData, {
        formId: this.formId,
        objectId: this.props.objectId,
        objectType: this.props.objectType,
      }),
    })
  }

  _initialData = () => {
    if (!this.props.objectId) return this.props.objectInitialData;
    return this._loadFullObject().then(object => {
      return Object.assign({}, this.props.objectInitialData,
          (object.rawData || {}))
    })
  }

  _loadFullObject = () => {
    return dataHelpers.loadFullObject(this.props).then(object => {
      if (!object) {
        const err = new Error();
        err.formErrorMessage = `The ${this._objectName()} you attempted to access with ID ${this.props.objectId} has been deleted. The user who deleted this record may be able to recover it from the Salesforce.com Recycle Bin. Deleted data is stored in the Recycle Bin for 15 days.`
        throw err
      }
      return object
    })
  }

  _handleFormLoadingErrors = (error) => {
    let msg = `Unable to load the form for ${this._objectName()}`
    if (error.formErrorMessage) msg = error.formErrorMessage;
    if (!error.reportedToSentry) {
      SalesforceActions.reportError(error, this.props);
    }
    return this.setState({formLoadingErrorMsg: msg});
  }

  _onSubmit = () => {
    const formData = formDataHelpers.cloneFormWithoutErrors(this.state.formData);
    this.setState({submitting: true, formData: formData})
    const {formPostData, relatedObjectsData} = GeneratedFormToSalesforceAdapter.extract(formData);

    this._submittedName = formPostData.Name || formPostData.Email
    this._action = this.props.objectId ? "Edit" : "Create";
    Actions.recordUserEvent(`Salesforce Object ${this._action} Submitted`, {
      sObjectId: this.props.objectId,
      sObjectType: this.props.objectType,
      sObjectName: this._submittedName,
    });

    formDataHelpers.validateForm(formData).then(() => {
      const t = new SyncbackSalesforceObjectTask({
        objectId: this.props.objectId,
        objectType: this.props.objectType,
        contextData: formData.contextData,
        formPostData: formPostData,
        relatedObjectsData: relatedObjectsData,
      });
      Actions.queueTask(t);
    }).catch((validationErrors = {}) => {
      const newData = formDataHelpers.formDataWithValidationErrors(formData, validationErrors);
      Actions.recordUserEvent(`Salesforce Object ${this._action} Errored`, {
        errorType: "LocalValidationError",
        errorCode: "LOCAL_FORM_VALIDATION_ERROR",
        errorMessage: this._localErrorsForAnalytics(validationErrors),
        sObjectId: this.props.objectId,
        sObjectType: this.props.objectType,
        sObjectName: this._submittedName,
      });
      this.setState({formData: newData, submitting: false})
      // Don't rethrow
    })
  }

  _localErrorsForAnalytics(validationErrors = {}) {
    return _.uniq(_.values(validationErrors).map(({message}) => message))
    .sort().join(", ")
  }

  _remoteErrorsForAnalytics(apiError = {}) {
    const msg = (apiError.body || [])[0] || apiError.message
    return [`${apiError.errorCode}: ${msg}`]
  }

  _onDeleteSuccess = ({objectId}) => {
    if (this.props.objectId === objectId) { NylasEnv.close() }
  }

  _onSyncbackFailed = ({contextData, error}) => {
    if (contextData.formId !== this.formId) return;
    if (!this.state.formData) return;
    Actions.recordUserEvent(`Salesforce Object ${this._action} Errored`, {
      errorType: error.constructor.name,
      errorCode: error.errorCode,
      errorMessage: error.message,
      sObjectId: this.props.objectId,
      sObjectType: this.props.objectType,
      sObjectName: this._submittedName,
    });
    this.setState({
      submitting: false,
      formData: formDataHelpers.formDataWithAPIErrors(this.state.formData, error),
    })
  }

  _onSyncbackSuccess = ({contextData} = {}) => {
    if (contextData.formId !== this.formId) return;
    this._closingDueToObjectSuccess = true;
    Actions.recordUserEvent(`Salesforce Object ${this._action} Succeeded`, {
      sObjectId: this.props.objectId,
      sObjectType: this.props.objectType,
      sObjectName: this._submittedName,
    });
    setTimeout(() => { NylasEnv.close(); }, 20)
  }

  _onBeforeUnload = () => {
    SalesforceActions.salesforceWindowClosing({
      contextData: this.state.formData.contextData,
      closingDueToObjectSuccess: this._closingDueToObjectSuccess,
    });
    return true;
  }

  _objectName() {
    return _str.titleize(_str.humanize(this.props.objectType))
  }

  render() {
    if (!this.state.formData) {
      return (
        <div className="salesforce-object-form">
          <Spinner visible withCover />
        </div>
      )
    }

    if (this.state.formLoadingErrorMsg) {
      return (
        <div className="salesforce-object-form schema-error">
          {this.state.formLoadingErrorMsg}
        </div>
      )
    }

    return (
      <div className="salesforce-object-form-wrap">
        <div className="salesforce-object-form">
          <RemoveControls
            objectId={this.props.objectId}
            objectType={this.props.objectType}
          />
          <GeneratedForm
            {...this.state.formData}
            style={{zIndex: 0}}
            onSubmit={this._onSubmit}
            onChange={formData => this.setState({formData})}
          />
          <Spinner visible={this.state.submitting} withCover />
        </div>
      </div>
    )
  }
}

export default SalesforceObjectForm
