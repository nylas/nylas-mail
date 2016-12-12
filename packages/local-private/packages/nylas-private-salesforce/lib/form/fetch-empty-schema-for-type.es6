import {DatabaseStore} from 'nylas-exports';
import SalesforceAPI from '../salesforce-api'
import SalesforceSchema from '../models/salesforce-schema';
import SalesforceActions from '../salesforce-actions';
import SalesforceObjectPicker from './salesforce-object-picker'
import SalesforceSchemaAdapter from './salesforce-schema-adapter';

/**
 * Given a Salesforce object type, we resolve a GeneratedForm schema.
 */
class FetchEmptySchemaForType {
  run(objectType) {
    return Promise.resolve(objectType)
    .then(this._loadSchemaFromDatabase)
    .then(this._addCustomFormTypes)
    .then(this._verifySchemaValidity)
    .then(({genFormSchema, isValid}) => {
      if (isValid) return genFormSchema;
      return Promise.resolve(objectType)
      .then(this._describeLayouts)
      .then(this._fetchDefaultLayout)
      .then(SalesforceSchemaAdapter.convertFullEditLayout.bind(SalesforceSchemaAdapter))
      .then(this._saveGenFormSchema)
    })
    // We allow all errors to propagate up so they can be caught by the
    // caller and displayed to the user.
  }

  _loadSchemaFromDatabase = (objectType) => {
    return DatabaseStore.findBy(SalesforceSchema, {objectType})
    .order(SalesforceSchema.attributes.createdAt.descending())
    .limit(1)
  }

  _addCustomFormTypes(formSchema = {}) {
    const fieldsets = formSchema.fieldsets || []
    for (const fieldset of fieldsets) {
      const formItems = fieldset.formItems || []
      for (const formItem of formItems) {
        if (formItem.type === "reference") {
          formItem.customComponent = SalesforceObjectPicker
        }
      }
    }
    return formSchema
  }

  _verifySchemaValidity = (genFormSchema = {}) => {
    if (!(genFormSchema instanceof SalesforceSchema)) {
      return {genFormSchema, isValid: false}
    }
    const noData = (genFormSchema.fieldsets || []).length === 0;
    const fieldError = this._hasInvalidFields(genFormSchema);

    if (noData || fieldError) {
      console.warn("The schema in the DB is malformed!", genFormSchema, {noData, fieldError});
      return DatabaseStore.inTransaction(t => t.unpersistModel(genFormSchema))
      .then(() => {
        return {genFormSchema, isValid: false}
      })
    }
    return {genFormSchema, isValid: true}
  }

  _hasInvalidFields = (genFormSchema) => {
    const fieldsets = genFormSchema.fieldsets || []
    if (fieldsets.length === 0) return "no fieldsets";
    for (const fieldset of fieldsets) {
      if (!fieldset.id) return "no fieldset id";
      const formItems = fieldset.formItems || []
      if (formItems.length === 0) return "empty form items";

      for (const formItem of formItems) {
        if (!formItem.id) return "formItem with no Id";

        if (formItem.type !== "EmptySpace" && !formItem.name) {
          return "formItem has no name";
        }

        if (formItem.type === "reference") {
          /**
           * We enfore the Id format since we use that format to
           * pre-populate fields from existing objects in the
           * SalesforceObjectPicker.
           */
          if (formItem.referenceTo.length === 0) return "empty referenceTo";
          if (formItem.referenceType === "hasMany") {
            if (!/.+Ids$/.test(formItem.name)) {
              return `Invalid hasMany name: ${formItem.name}`
            }
          } else if (formItem.referenceType === "hasManyThrough") {
            if (!/.+Ids$/.test(formItem.name)) {
              return `Invalid hasManyThrough name: ${formItem.name}`
            }
            if (!formItem.referenceThrough) return "No referenceThough";
            if (!formItem.referenceThroughSelfKey) return "No SelfKey";
            if (!formItem.referenceThroughForeignKey) return "No ForeignKey";
          } else {
            if (!/.+Id$/.test(formItem.name)) {
              return `Invalid belongsTo name: ${formItem.name}`
            }
          }
        }
      }
    }
    return false;
  }

  _describeLayouts = (objectType) => {
    return SalesforceAPI.makeRequest({
      path: `/sobjects/${objectType}/describe/layouts`,
    }).then((layoutDescription) => {
      return {layoutDescription, objectType}
    })
  }

  // The /describe endpoint returns a list of `recordTypeMappings` that
  // may include one or more layouts. In many cases there will only be 1
  // layout and 1 default to choose from. We can immediately return the
  // layout in this case.
  //
  // In other cases we will need to separately fetch the raw layout from
  // the API
  _fetchDefaultLayout = ({layoutDescription, objectType}) => {
    try {
      const rawLayout = SalesforceSchemaAdapter.defaultLayout(layoutDescription);
      if (rawLayout) return {rawLayout, objectType}

      const path = SalesforceSchemaAdapter.pathForDefaultLayout(layoutDescription)

      return SalesforceAPI.makeRequest({path: path})
      .then((rl) => { return {rawLayout: rl, objectType} })
    } catch (error) {
      error.reportedToSentry = true;
      SalesforceActions.reportError(error, {objectType, layoutDescription});
      throw error;
    }
  }

  _saveGenFormSchema = (genFormSchemaJSON) => {
    const genFormSchema = new SalesforceSchema(genFormSchemaJSON);
    const schema = this._addCustomFormTypes(genFormSchema)
    return DatabaseStore.inTransaction(t => {
      return t.persistModel(schema).then(() => schema);
    });
  }
}
export default new FetchEmptySchemaForType()
