import { Utils } from 'nylas-exports';
import _ from 'underscore';
import SalesforceActions from '../salesforce-actions'

// Salesforce provides "Layouts", which are custom specifications on what
// various object creation / edit forms look like. The data here includes
// row & column information and fieldset data. Layouts are available at
// the: /sobjects/{OBJECT_TYPE}/describe/layouts endpoint
//
// Salesforce also provides a separate schema that defines the total fields
// of a particular object type. This is the ultimate truth on what the API
// will and will not accept. It lists all fields of an object and crucially
// indicates if it is `updateable` (aka user editable), and if it's
// `nillable` (aka required). The set of fields are availabe at the:
// /sobjects/{OBJECT_TYPE}/describe endpoint.
//
// We need to look at both the layout and the schema to determine the
// proper way to display the form (via the layout) and what to mark as
// required & editable (via the schema).
//
//
// This class converts Schemas and Layouts into an object that
// the GeneratedForm component can understand.
//
// A Salesforce /describe block (the schema) looks like (as of API v37 Sept
// 2016):
// rawData = {
//   "actionOverrides": [],
//   "activateable": false,
//   "childRelationships": [],
//   "compactLayoutable": true,
//   "createable": true,
//   "custom": false,
//   "customSetting": false,
//   "deletable": true,
//   "deprecatedAndHidden": false,
//   "feedEnabled": true,
//   "fields": [
//     {
//       "aggregatable": true,
//       "autoNumber": false,
//       "byteLength": 18,
//       "calculated": false,
//       "calculatedFormula": null,
//       "cascadeDelete": false,
//       "caseSensitive": false,
//       "controllerName": null,
//       "createable": false,
//       "custom": false,
//       "defaultValue": null,
//       "defaultValueFormula": null,
//       "defaultedOnCreate": true,
//       "dependentPicklist": false,
//       "deprecatedAndHidden": false,
//       "digits": 0,
//       "displayLocationInDecimal": false,
//       "encrypted": false,
//       "externalId": false,
//       "extraTypeInfo": null,
//       "filterable": true,
//       "filteredLookupInfo": null,
//       "groupable": true,
//       "highScaleNumber": false,
//       "htmlFormatted": false,
//       "idLookup": true,
//       "inlineHelpText": null,
//       "label": "Lead ID",
//       "length": 18,
//       "mask": null,
//       "maskType": null,
//       "name": "Id",
//       "nameField": false,
//       "namePointing": false,
//       "nillable": false,
//       "permissionable": false,
//       "picklistValues": [],
//       "precision": 0,
//       "queryByDistance": false,
//       "referenceTargetField": null,
//       "referenceTo": [],
//       "relationshipName": null,
//       "relationshipOrder": null,
//       "restrictedDelete": false,
//       "restrictedPicklist": false,
//       "scale": 0,
//       "soapType": "tns:ID",
//       "sortable": true,
//       "type": "id",
//       "unique": false,
//       "updateable": false,
//       "writeRequiresMasterRead": false
//     }
//     {}
//     ...
//   ],
//   "keyPrefix": "00Q",
//   "label": "Lead",
//   "labelPlural": "Leads",
//   "layoutable": true,
//   "listviewable": null,
//   "lookupLayoutable": null,
//   "mergeable": true,
//   "mruEnabled": true,
//   "name": "Lead",
//   "namedLayoutInfos": [],
//   "networkScopeFieldName": null,
//   "queryable": true,
//   "recordTypeInfos": [],
//   "replicateable": true,
//   "retrieveable": true,
//   "searchLayoutable": true,
//   "searchable": true,
//   "supportedScopes": [
//     {
//       "label": "All leads",
//       "name": "everything"
//     },
//   ],
//   "triggerable": true,
//   "undeletable": true,
//   "updateable": true,
//   "urls": {}
// }
//
// A Salesforce full layout looks like (as of API v37 Aug 2016):
// rawData = {
//   recordTypeMappings: [
//     {
//       "available": true,
//       "defaultRecordTypeMapping": true,
//       "layoutId": "00h41000000TRMmAAO",
//       "master": false,
//       "name": "Master",
//       "picklistsForRecordType": [],
//       "recordTypeId": "01241000000Yg3MAAS",
//       "urls": {
//         "layout": "/services/data/v37.0/sobjects/Opportunity/describe/layouts/01241000000Yg3MAAS"
//       }
//     },
//   ],
//   recordTypeSelectorRequired: []
//   layouts: [
//     { // layout
//       id : "00h41000000TRMtAAO"
//       buttonLayoutSection : {}
//       detailLayoutSections : []
//       feedView : null
//       highlightsPanelLayoutSection : null
//       multirowEditLayoutSections : []
//       offlineLinks : []
//       quickActionList : {}
//       relatedContent : {}
//       relatedLists : []
//       editLayoutSections: [ // may be many layoutSections aka fieldsets
//         { // layoutSection
//           rows: 8
//           columns: 2
//           heading: "Contact Information"
//           parentLayoutId: "00h41000000TRMt"
//           tabOrder: "TopToBottom"
//           useCollapsibleSection: false
//           useHeading: true
//           layoutRows: [
//             { // layoutRow
//               numItems: 2
//               layoutItems: [
//                 { // layoutItem
//                   editableForNew: false
//                   editableForUpdate: false
//                   label: "Contact Owner"
//                   placeholder: false
//                   required: true
//                   layoutComponents: [
//                     { // layoutComponent
//                       displayLines: 1
//                       fieldType: "string"
//                       tabOrder: 32
//                       type: "Field"
//                       value: "Name"
//
//                       components: [
//                         {LAYOUT_COMPONENT}
//                         ... a couple layoutComponent
//                       ]
//
//                       details: {
//                         aggregatable : true
//                         autoNumber : false
//                         byteLength : 18
//                         calculated : false
//                         calculatedFormula : null
//                         cascadeDelete : false
//                         caseSensitive : false
//                         controllerName : null
//                         createable : true
//                         custom : false
//                         defaultValue : null
//                         defaultValueFormula : null
//                         defaultedOnCreate : false
//                         dependentPicklist : false
//                         deprecatedAndHidden : false
//                         digits : 0
//                         displayLocationInDecimal : false
//                         encrypted : false
//                         externalId : false
//                         extraTypeInfo : null
//                         filterable : true
//                         filteredLookupInfo : null
//                         groupable : true
//                         highScaleNumber : false
//                         htmlFormatted : false
//                         idLookup : false
//                         inlineHelpText : null
//                         label : "Account ID"
//                         length : 18
//                         mask : null
//                         maskType : null
//                         name : "AccountId"
//                         nameField : false
//                         namePointing : false
//                         nillable : true
//                         permissionable : true
//                         picklistValues : [
//                           {
//                             active : true
//                             defaultValue : false
//                             label : "Mr."
//                             validFor : null
//                             value : "Mr."
//                           }
//                           ...
//                         ]
//                         precision : 0
//                         queryByDistance : false
//                         referenceTargetField : null
//                         referenceTo : [
//                           "Account"
//                         ]
//                         relationshipName : "Account"
//                         relationshipOrder : null
//                         restrictedDelete : false
//                         restrictedPicklist : false
//                         scale : 0
//                         soapType : "tns:ID"
//                         sortable : true
//                         type : "reference"
//                         unique : false
//                         updateable : true
//                         writeRequiresMasterRead : false
//                       } // details
//                     } // layoutComponent. Usually only 1 layoutComponent
//                   ]
//                 }
//                 {LAYOUT_ITEM} // layoutItem. Exactly num of columns
//               ]
//             } // layoutRow
//             ... many layoutRows
//           ]
//         } // layoutSection
//         ... many layoutSections (aka fieldsets)
//       ]
//     } // layout. Usually only 1 layout
//   ]
// } // rawData
//
//
export default class SalesforceSchemaAdapter {

  // The /describe endpoint actually returns a listing of available
  // "Record Layout" objects. For a given Salesforce record (like an
  // opportunity), there may be many different layouts (aka record
  // layouts) exposed to many different types of users. SREs, Account
  // Managers, and Marketers may have different fields to fill out for the
  // same Opportunity.
  //
  // We first attempt to find the "default" layout for the user. This is
  // annotated by the `defaultRecordTypeMapping` attribute of each of the
  // record types in the `recordTypeMappings` field.
  //
  // If we can't find one, we fall back to the record mapping labeled as
  // "master".
  //
  // Sometimes the layouts automatically come down with the describe
  // block. If there are 3 or more record mappings, they need to be
  // separately fetched. We detect this and return the url of the layout
  // to fetch so we can asynchronously grab that later.
  static defaultLayout(layoutDescription = {}) {
    if (!_.isArray(layoutDescription.layouts)) return null;
    if (layoutDescription.layouts.length === 1) {
      return layoutDescription.layouts[0]
    }
    const defaultRecordType = this.defaultRecordType(layoutDescription);
    const id = defaultRecordType.layoutId;
    return _.findWhere(layoutDescription.layouts, {id: id})
  }

  static defaultRecordType(layoutDescription = {}) {
    const recordTypes = layoutDescription.recordTypeMappings
    if (!_.isArray(recordTypes)) {
      throw new Error("Unsupported Salesforce layout: No Record Type mappings")
    }
    let defaultRecordType = _.findWhere(recordTypes, {defaultRecordTypeMapping: true});

    if (defaultRecordType) return defaultRecordType

    defaultRecordType = _.findWhere(recordTypes, {master: true});

    if (!defaultRecordType) {
      throw new Error("Unsupported Salesforce layout: No default Record Type nor Master Record Type ")
    }

    return defaultRecordType
  }

  static pathForDefaultLayout(layoutDescription = {}) {
    const recordType = this.defaultRecordType(layoutDescription) || {}
    const path = (recordType.urls || {}).layout;
    if (!path) {
      throw new Error("Unsupported Salesforce layout: No url for default record type")
    }
    return path.slice(path.search("/sobjects"))
  }

  // As returned from the SObject Layouts endpoint
  // https://www.salesforce.com/us/developer/docs/api_rest/
  //
  // See ../spec/fixtures/opportunity-layouts.json for an example schema
  //
  // See /src/components/generated-form.cjsx for the output schema
  static convertFullEditLayout({objectType, rawLayout = {}}) {
    try {
      if ((rawLayout.editLayoutSections || []).length === 0) {
        throw new Error("Unsupported Salesforce layout: No editLayoutSections")
      }

      if (!rawLayout.id) {
        throw new Error("Unsupported Salesforce layout: No layout Id")
      }

      let fieldsets = rawLayout.editLayoutSections
      fieldsets = fieldsets.map((layoutSection) => {
        return this.normalizeFieldset(layoutSection);
      });
      fieldsets = this.addCustomFieldsets(objectType, fieldsets);

      const genFormSchemaJSON = {
        id: rawLayout.id,
        schemaType: "full",
        objectType,
        fieldsets,
        createdAt: new Date(),
      };
      return genFormSchemaJSON;
    } catch (error) {
      error.reportedToSentry = true;
      SalesforceActions.reportError(error, {objectType, rawLayout});
      throw error;
    }
  }

  // A layoutSection (aka fieldset) needs to be normalized and flattened
  // from the Salesforce schema
  static normalizeFieldset(layoutSection = {}) {
    // We flatten all layoutItems in all rows to a single array and record
    // the row and column they're supposed to appear.
    let normalizedLayoutItems = [];
    const layoutRows = layoutSection.layoutRows || []
    for (let rowIndex = 0; rowIndex < layoutRows.length; rowIndex++) {
      const layoutRow = layoutRows[rowIndex]
      const layoutItems = layoutRow.layoutItems || []
      for (let colIndex = 0; colIndex < layoutItems.length; colIndex++) {
        const layoutItem = layoutItems[colIndex];
        layoutItem.row = rowIndex;
        layoutItem.column = colIndex;
        normalizedLayoutItems.push(layoutItem);
      }
    }

    // Since some layoutItems contain one or more layoutComponents (e.g.
    // the Mailing Address layoutItem has 5 layoutComponents for the
    // Street, City, State, etc), we flatten them all out.
    normalizedLayoutItems = normalizedLayoutItems.map(this.normalizeLayoutItem);
    const flattenedLayoutItems = _.compact(_.flatten(normalizedLayoutItems));
    const formItems = flattenedLayoutItems.map(this.layoutItemToFormItem.bind(this));

    return {
      id: Utils.generateTempId(),
      rows: layoutSection.rows,
      columns: layoutSection.columns,
      heading: layoutSection.heading,
      formItems: formItems,
      useHeading: layoutSection.useHeading,
    };
  }

  static normalizeLayoutItem(rawLayoutItem = {}) {
    const layoutItem = _.clone(rawLayoutItem);
    const layoutComponent = (layoutItem.layoutComponents || [])[0];
    if (!layoutComponent) { return null; }
    delete layoutItem.layoutComponents

    const components = layoutComponent.components || []
    if (components.length > 0) {
      return components.map((_component = {}) => {
        const component = _.extend({},
          layoutItem, // NOTE: We want the 'label' of the layoutItem overridden
          _component,
          _component.details);
        delete component.details;
        return component;
      });
    }
    const normalizedLayoutItem = _.extend({},
      layoutComponent,
      (layoutComponent.details || {}),
      layoutItem); // NOTE: we want to use the 'label' of the layoutItem
    delete normalizedLayoutItem.details;
    return normalizedLayoutItem;
  }

  static layoutItemToFormItem(layoutItem = {}) {
    return {
      id: Utils.generateTempId(),
      row: layoutItem.row || 0,
      type: this.typeMap(layoutItem.type),
      name: layoutItem.name, // can be null in the EmptySpace case.
      label: layoutItem.label,
      column: layoutItem.column,
      length: layoutItem.length,
      multiple: layoutItem.type === "multipicklist",
      tabIndex: layoutItem.tabOrder || 0,
      required: this._isRequired(layoutItem),
      placeholder: this._placeholder(layoutItem),
      referenceTo: this._referenceTo(layoutItem),
      defaultValue: layoutItem.defaultValue, // Used in SmartFields
      selectOptions: (layoutItem.picklistValues || []).map(this.picklistOptionToFormOption),
      editableForNew: layoutItem.editableForNew,
      editableForUpdate: layoutItem.editableForUpdate,
      // Note the disabled field is calculated in the generatedForm via
      // `editableForNew` and `editableForUpdate`
    };
  }

  static picklistOptionToFormOption(picklistOption = {}) {
    return {
      label: picklistOption.label,
      value: picklistOption.value,
      validFor: picklistOption.validFor,
      defaultValue: picklistOption.defaultValue,
    };
  }

  static _isRequired(layoutItem) {
    if (layoutItem.type === "EmptySpace") return false;

    // It doesn't make sense to have a checkbox be required since when
    // displayed it always deafults to "false". HTML forms erroneously bug
    // you when a checkbox's value is null, when in reality users perceive
    // that to simply be "unchecked" aka "false".
    if (layoutItem.type === "boolean") return false;

    return layoutItem.nillable === false
  }

  static _referenceTo(layoutItem) {
    return layoutItem.referenceTo || [];
  }

  static _placeholder(layoutItem) {
    if (layoutItem.type === "reference") {
      let label = (layoutItem.label || "").toLowerCase();
      if (label.slice(-3) === " id") { label = label.slice(0, -3); }
      const a = label[0] === "a" || label[0] === "e" || label[0] === "i" || label[0] === "o" || label[0] === "u" ? "an" : "a";
      return `Create or search for ${a} ${label}`;
    }
    return layoutItem.label;
  }

  static typeMap(type) {
    const knownTypes = {
      "int": "number",
      "phone": "tel",
      "string": "text",
      "address": "textarea",
      "boolean": "checkbox",
      "percent": "number",
      "currency": "number",
      "picklist": "select",
      "textarea": "textarea",
      "EmptySpace": "EmptySpace",
      "multipicklist": "select",
    };
    return knownTypes[type] != null ? knownTypes[type] : type;
  }

  static addCustomFieldsets(objectType, fieldsets = []) {
    if (objectType === "Contact") {
      fieldsets.unshift(this._opportunitiesInContacts());
    } else if (objectType === "Opportunity") {
      fieldsets.unshift(this._contactsInOpportunities());
    } else if (objectType === "Account") {
      fieldsets.unshift(this._contactsInAccounts());
    }
    return fieldsets;
  }

  // Contacts are linked to Opportunities through a trivial object called
  // an OpportunityContactRole. Instead of popping up a whole new object
  // creator, we provide a more user-friendly interface to pick an
  // Opportunity through a standard picker and create the association
  // object in the background for the users.
  //
  // Since any additional data will throw an error if fully submitted to
  // the SalesforceAPI, we use the "hasManyThrough" `refereneType`
  static _opportunitiesInContacts() {
    return {
      id: Utils.generateTempId(),
      heading: "Related Opportunities",
      useHeading: true,
      formItems: [{
        id: Utils.generateTempId(),
        row: 0,
        type: "reference",
        name: "OpportunityIds",
        label: "Opportunities",
        column: 0,
        tabIndex: 0,
        required: false,
        multiple: true,
        placeholder: "Create or search for opportunities",
        defaultValue: null,
        referenceTo: ["Opportunity"],
        referenceType: "hasManyThrough",
        referenceThrough: "OpportunityContactRole",
        referenceThroughSelfKey: "identifier",
        referenceThroughForeignKey: "relatedToId",
      }],
    };
  }

  static _contactsInOpportunities() {
    return {
      id: Utils.generateTempId(),
      heading: "Contacts for Opportunity",
      useHeading: true,
      formItems: [{
        id: Utils.generateTempId(),
        row: 0,
        type: "reference",
        name: "ContactIds",
        label: "Contacts",
        column: 0,
        tabIndex: 0,
        required: false,
        multiple: true,
        placeholder: "Create or search for contacts",
        defaultValue: null,
        referenceTo: ["Contact"],
        referenceType: "hasManyThrough",
        referenceThrough: "OpportunityContactRole",
        referenceThroughSelfKey: "relatedToId",
        referenceThroughForeignKey: "identifier",
      }],
    };
  }

  static _contactsInAccounts() {
    return {
      id: Utils.generateTempId(),
      heading: "Contacts for Account",
      useHeading: true,
      formItems: [{
        id: Utils.generateTempId(),
        row: 0,
        type: "reference",
        name: "ContactIds",
        label: "Contacts",
        column: 0,
        tabIndex: 0,
        required: false,
        multiple: true,
        placeholder: "Create or search for contacts",
        defaultValue: null,
        referenceTo: ["Contact"],
        referenceType: "hasMany",
      }],
    };
  }
}
