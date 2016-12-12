import _ from 'underscore';
import {Utils} from 'nylas-exports'
import SalesforceObject from '../models/salesforce-object'
import PendingSalesforceObject from './pending-salesforce-object'

export function formItemEach(formData, eachFn) {
  if (!_.isFunction(eachFn)) { return; }
  const fieldsets = formData.fieldsets || []
  for (const fieldset of fieldsets) {
    const formItems = fieldset.formItems || []
    for (const formItem of formItems) {
      eachFn(formItem);
    }
  }
}

/**
 * Many forms will want to initialize new forms. When we do this we need
 * to pass along serialized data of the current form state to a new
 * window. Form values can be full of PendingSalesforceObjects and
 * SalesforceObjects that we'll need to serialize properly.
 */
export function serializeRawFormValue(value) {
  if (value === null || value === undefined) return value;
  if (typeof value === "string") return value;
  if (value instanceof SalesforceObject) return value.id
  if (value instanceof PendingSalesforceObject) return value.toJSON();
  if (value.pendingSalesforceObject) return value;
  if (value.id) return value.id;
  if (_.isArray(value)) return _.compact(value.map(serializeRawFormValue))
  return value
}

/**
 * A Salesforce REQUIRED_FIELD_MISSING API error has the following
 * schema:
 *
 * rawError = [
 *   {
 *     errorCode: "REQUIRED_FIELD_MISSING",
 *     fields: ["AccountId", "LastName"]
 *   }
 * ]
 */
export function validateForm(formData) {
  const validationErrors = {}
  let valid = true;
  formItemEach(formData, (formItem) => {
    if (formItem.required &&
        ((formItem.value === null || formItem.value === undefined) ||
         formItem.value.length === 0)) {
      valid = false;
      validationErrors[formItem.id] = {
        id: formItem.id,
        message: "This is a required field",
      }
    }
  })
  if (valid) return Promise.resolve();
  return Promise.reject(validationErrors)
}


/**
 * A frontend form validation error has the following schema:
 *
 * validationErrors = {
 *   "local-123": {
 *     id: "local-123",
 *     message: "This is a required field",
 *   }
 *   "some-form-item-id": {
 *     id: "some-form-item-id",
 *     message: "Some error message",
 *   }
 * }
 */
export function formDataWithValidationErrors(_formData, validationErrors = {}) {
  const formData = Utils.deepClone(_formData);
  formData.errors.formItemErrors = validationErrors;
  return formData
}

export function cloneFormWithoutErrors(formData) {
  const newFormData = Utils.deepClone(formData);
  newFormData.errors = {};
  return newFormData;
}

export function mergeSalesforceError(formData, error) {
  if (error.errorCode !== "REQUIRED_FIELD_MISSING") {
    return formData;
  }
  formData.errors.formItemErrors = {};
  formItemEach(formData, (formItem) => {
    if (!error.fields.includes(formItem.name)) return;
    formData.errors.formItemErrors[formItem.id] = {
      id: formItem.id,
      message: "This is a required field",
    };
  })
  return formData
}

// Merges errors with formData and returns a new shallow of formData
// See the generated form error data schema in:
// src/components/generated-form
export function formDataWithAPIErrors(_formData, error = {}) {
  let formData = Utils.deepClone(_formData);
  // Came from Edgehill API
  if (error.errorCode === "REQUIRED_FIELD_MISSING") {
    formData.errors = {};
    formData = mergeSalesforceError(formData, error.body[0]);
    return formData;
  }
  const msg = error.message || "Unknown error with the Salesforce API"
  if (error.name === "APIError") {
    formData.errors = {
      formError: { message: msg },
      formItemErrors: {},
    };
  } else {
    console.log("An unexpected error occurred", error);
    formData.errors = {
      formError: { message: (error.message || "An unexpected error occurred") },
      formItemErrors: {},
    };
  }
  return formData;
}
