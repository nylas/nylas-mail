import _ from 'underscore'
import moment from 'moment'
import {Utils, Contact, DatabaseStore} from 'nylas-exports'

import SalesforceEnv from '../salesforce-env'
import SalesforceObject from '../models/salesforce-object'
import PendingSalesforceObject from './pending-salesforce-object'

/**
 * This attempts to pre-fill as much data as possible in generic
 * Salesforce forms. We keep a known mapping of Nylas Fields to common
 * Salesforce fields.
 *
 * The initialSchema is the blank schema loaded via
 * `FetchEmptySchemaForType`
 *
 * contextData is data passed into a form from the form's creator. This
 * provides context and additional data (like related Contacts) to the
 * form so we can have something to pre-fill from.
 *
 * objectInitialData is the combination of initially passed in data to the
 * form and existing data if the object already exists and we're editing
 * it.
 *
 * This uses the Clearbit API to load contextual information about various
 * contacts.
 */
class SmartFields {
  fillForm = (args = {}) => {
    return Promise.resolve(this.checkArgs(args))
    .then(this.addSelfAsOwner)
    .then(this.loadAssociatedContact)
    .then(this.formItemEach((formItem) => {
      if (this.isUnfillable(formItem)) return formItem;
      return Promise.resolve(formItem)
      .then(this.fillFromInitialData(args.objectInitialData))
      .then(this.fillJoinedReferences(args))
      .then(this.fillFromDefaultValue)
      .then(this.fillFromKnownFields)
      .then(this.fillFromClearbit(args))
      .then(this.normalizeValue)
    })).then((formData) => formData)
  }

  checkArgs(args) {
    if (!args.initialSchema) {
      throw new Error("Need initial schema")
    }
    return args
  }

  addSelfAsOwner = (args) => {
    return SalesforceEnv.loadIdentity().then(identity => {
      args.objectInitialData.OwnerId = identity.id;
      return args
    });
  }

  loadAssociatedContact = (args) => {
    const {focusedNylasContactData} = args.initialSchema.contextData;
    if (!focusedNylasContactData) return args;
    if (focusedNylasContactData.id) {
      return DatabaseStore.find(Contact, focusedNylasContactData.id)
      .then((contact) => {
        args.initialSchema.contextData.contact = contact;
        return args
      })
    }
    args.initialSchema.contextData.contact = new Contact({
      name: focusedNylasContactData.name,
      email: focusedNylasContactData.email,
    });
    return Promise.resolve(args)
  }

  formItemEach(eachFn) {
    return (args) => {
      const formData = Utils.deepClone(args.initialSchema);
      return Promise.each(formData.fieldsets, (fieldset) => {
        return Promise.each(fieldset.formItems, (formItem) => {
          // Designed to update formData via each formItem in place
          return eachFn(formItem)
        })
      }).then(() => formData)
    }
  }

  hasEmptyValue(formItem) {
    if (typeof formItem.value === 'string' || _.isArray(formItem.value)) {
      return formItem.value.length === 0
    }
    return (formItem.value === null || formItem.value === undefined)
  }

  isUnfillable = (formItem) => {
    return formItem.type === "EmptySpace" || !formItem.name
  }

  fillFromInitialData = (objectInitialData = {}) => {
    return (formItem) => {
      if (formItem.name in objectInitialData) {
        formItem.value = objectInitialData[formItem.name];
      }
      return formItem;
    }
  }

  /**
   * For "hasMany" and "hasManyThrough" reference types. Based on the
   * objectId we lookup all related objects for that object given the
   * reference flags stored on the formItem's value.
   *
   * The formItem's value for a type reference must always be an array.
   * The array must end up filled with zero or more SalesforceObjects
   *
   * To resolve these references properly we make use of the following
   * formItem fields:
   *
   * - type === "reference"
   * - referenceTo
   * - referenceType
   * - referenceThrough
   * - referenceThroughSelfKey
   * - referenceThroughForeignKey
   *
   * See SalesforceSchemaAdapter for a place we insert objects with
   * more complex referenceTypes
   */
  fillJoinedReferences = (args) => {
    const objectId = args.initialSchema.contextData.objectId;

    return (formItem) => {
      if (formItem.type !== "reference") return formItem;
      if (!formItem.referenceType) formItem.referenceType = "belongsTo";

      return this._resolveInitialRefs(formItem.value, formItem.referenceTo, args.initialSchema.contextData).then((value) => {
        formItem.value = value;

        if (!objectId) return formItem;

        if (formItem.referenceType === "hasMany") {
          // Example: An Account hasMany Contacts. Each Contact has an
          // AccountId pointer in their "relatedToId" field
          return DatabaseStore.findAll(SalesforceObject, {
            type: formItem.referenceTo,
            relatedToId: objectId,
          }).then((objs = []) => {
            formItem.value = formItem.value.concat(objs);
            return formItem
          })
        } else if (formItem.referenceType === "hasManyThrough") {
          // Example: A Contact hasMany Opportunities through
          // OpportunityContactRoles.
          //
          // For a given Contact, we can lookup OpportunityContactRoles by
          // the Contact's id. The referenceThroughSelfKey for a Contact is
          // the "identifier" field of an OpportunityContactRole. The
          // referenceThroughForeignKey for a Contact is the "relatedToId"
          // field of an OpportunityContactRole.
          const joinWhere = {type: formItem.referenceThrough}
          joinWhere[formItem.referenceThroughSelfKey] = objectId;
          return DatabaseStore.findAll(SalesforceObject, joinWhere)
          .then((joinItems = []) => {
            if (joinItems.length === 0) return [];
            const objIds = _.pluck(joinItems, formItem.referenceThroughForeignKey)
            return DatabaseStore.findAll(SalesforceObject, {
              type: formItem.referenceTo, id: objIds,
            })
          })
          .then((objs = []) => {
            formItem.value = formItem.value.concat(objs);
            return formItem
          })
        }

        // We get here if it's a "belongsTo" referenceType and the field
        // is blank & empty. In the "belongsTo" case there's nothing to
        // lookup, so we simply return the formItem.
        return formItem
      })
    }
  }

  /**
   * When we fill reference types, the key may already have a value
   * associated with it. That value represents objects we want to pre-fill
   * into a field, in addition to those we find already related to the
   * object. The value may come to us in a variety of formats.
   *
   * We return an array of zero or more SalesforceObject or
   * PendingSalesforceObject types.
   */
  _resolveInitialRefs = (rawValue = [], referenceTo) => {
    const ids = []
    const outValue = []
    const pendingJSON = []
    if (rawValue === null || rawValue === undefined) {
      return Promise.resolve(outValue)
    } else if (typeof rawValue === "string") {
      ids.push(rawValue)
    } else if (_.isArray(rawValue)) {
      for (const val of rawValue) {
        if (typeof val == "string") ids.push(val);
        if (val.pendingSalesforceObject) pendingJSON.push(val);
        if (val instanceof SalesforceObject) outValue.push(val);
        if (val instanceof PendingSalesforceObject) outValue.push(val);
      }
    } else if (rawValue.pendingSalesforceObject) {
      pendingJSON.push(rawValue)
    } else {
      return Promise.resolve(outValue)
    }

    return DatabaseStore.findAll(SalesforceObject, {
      type: referenceTo,
      id: ids,
    }).then((objs = []) => {
      return outValue.concat(objs).concat(pendingJSON.map((objJSON) => {
        /**
         * As initialData we can pass in the JSON of a
         * PendingSalesforceObject. We do this to initialize back
         * references to forms. The id of the JSON has been set to the
         * formId of the form creating the backref. That way if the
         * creating form closes, the creating form's ID will match with
         * our PendingSalesforceObject's ID, and we'll properly dismiss
         * the PendingSalesforceObject in the form.
         */
        return new PendingSalesforceObject(objJSON)
      }));
    })
  }

  fillFromDefaultValue = (formItem) => {
    if (!this.hasEmptyValue(formItem)) return formItem
    if (formItem.defaultValue && formItem.defaultValue.length > 0) {
      formItem.value = formItem.defaultValue
    }
    if (formItem.type === "checkbox") { formItem.value = false; }
    return formItem
  }

  fillFromKnownFields = (formItem) => {
    if (!this.hasEmptyValue(formItem)) return formItem;
    const knownFields = {
      CloseDate: () => moment().add(1, 'month').format("YYYY-MM-DD"),
      StageName: () => "Prospecting",
      ForecastCategoryName: () => "Pipeline",
      LeadStatus: () => "Working - Contacted",
    }
    if (formItem.name in knownFields) {
      formItem.value = knownFields[formItem.name]()
    }
    if (!this.hasEmptyValue(formItem)) formItem.prefilled = true;
    return formItem;
  }

  fillFromClearbit = (args) => {
    return (formItem) => {
      if (!this.hasEmptyValue(formItem)) return formItem;
      const contact = args.initialSchema.contextData.contact;
      const objectType = args.initialSchema.contextData.objectType;
      if (!contact || !this.hasEmptyValue(formItem)) return formItem;
      formItem.value = this.getFieldFromClearbit(contact, objectType, formItem.name)
      if (!this.hasEmptyValue(formItem)) formItem.prefilled = true;
      return formItem;
    }
  }

  normalizeValue = (formItem) => {
    if (this.hasEmptyValue(formItem)) return formItem;
    if (formItem.name.includes("LinkedIn")) {
      formItem.value = `https://linkedin.com/${formItem.value}`
    } else if (formItem.name === "FirstName") {
      if (formItem.value.includes("@")) {
        formItem.value = null
      }
    }
    if (this.hasEmptyValue(formItem)) formItem.prefilled = false;
    return formItem;
  }

  /**
   * This is the default field mapping between Clearbit's Enrichment
   * API for Persons (version 2016-01-04) and Companies
   * (version 2016-05-18), and a standard uncustomized Salesforce
   * environment
   *
   * TODO: Load a custom config from the `SalesforceEnv` that lets users
   * customize their field mappings.
   *
   * See https://dashboard.clearbit.com/docs#enrichment-api-company-api-attributes
   *
   */
  getFieldFromClearbit(contact, objectType, formItemName) {
    const cbPerson = "thirdPartyData.clearbit.rawClearbitData.person"
    const cbCompany = "thirdPartyData.clearbit.rawClearbitData.company"
    const personMapping = {
      Name: "name",
      Email: "email",
      Phone: "phone",

      Salutation: "",
      FirstName: "firstName",
      MiddleName: "",
      LastName: "lastName",
      Suffix: "",

      Company: `company,${cbPerson}.employment.name,${cbCompany}.name,guessCompanyFromEmail`,
      Title: `${cbPerson}.employment.title`,
      Department: `${cbPerson}.employment.role`,
      Website: `${cbCompany}.url`,

      Street: "",
      City: `${cbPerson}.city,${cbCompany}.city`,
      // StateCode: `${cbPerson}.stateCode,${cbCompany}.stateCode`,
      PostalCode: "",
      // CountryCode: `${cbPerson}.countryCode,${cbCompany}.countryCode`,

      LinkedIn__c: `${cbPerson}.linkedin.handle`,
      LinkedIn_personal_url__c: `${cbPerson}.linkedin.handle`,
    }
    const companyMapping = {
      Name: `${cbCompany}.name`,
      Website: `${cbCompany}.url`,
      Phone: `${cbCompany}.phone`,
      Description: `${cbCompany}.description`,
      Industry: `${cbCompany}.category.industry`,
      NumberOfEmployees: `${cbCompany}.metrics.employees`,
      BillingStreet: `${cbCompany}.geo.streetNumber+${cbCompany}.geo.streetName`,
      BillingCity: `${cbCompany}.geo.city`,
      // BillingStateCode: `${cbCompany}.geo.state`,
      BillingPostalCode: `${cbCompany}.geo.postalCode`,
      // BillingCountryCode: `${cbCompany}.geo.country`,
      ShippingStreet: `${cbCompany}.geo.streetNumber+${cbCompany}.geo.streetName`,
      ShippingCity: `${cbCompany}.geo.city`,
      // ShippingStateCode: `${cbCompany}.geo.state`,
      ShippingPostalCode: `${cbCompany}.geo.postalCode`,
      // ShippingCountryCode: `${cbCompany}.geo.country`,
    }
    const mapping = {
      Lead: personMapping,
      Contact: personMapping,
      Account: companyMapping,
      Opportunity: companyMapping,
    }
    const lookupPath = (mapping[objectType] || {})[formItemName]
    return Utils.resolvePath(lookupPath, contact)
  }
}

export default new SmartFields()
