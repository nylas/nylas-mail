/**
 * Converts the schema of a GeneratedForm to a data format that the
 * Salesforce object creation API understands
 *
 * https://www.salesforce.com/us/developer/docs/api_rest/
 * See:
 *   Using REST Resources > Using REST API Resources > Working with Records
 *   > Create a Record
 */
import _ from "underscore"
import SalesforceObject from '../models/salesforce-object'

class GeneratedFormToSalesforceAdapter {

  static extract(formData) {
    const relatedObjectsData = {};
    const formPostData = {};
    const fieldSets = formData.fieldsets || []

    fieldSets.forEach((fieldset) => {
      const formItems = fieldset.formItems || []
      formItems.forEach((formItem) => {
        if (formItem.type === "EmptySpace") { return; }

        if (!formItem.name) {
          console.error(formItem);
          throw new Error("This formItem doesnt have a name");
        }

        if (formItem.type === "reference") {
          if (_.isString(formItem.value)) {
            console.error(formItem);
            throw new Error("Invalid value for reference type")
          }

          const objIds = (formItem.value || []).filter((obj) => {
            return obj instanceof SalesforceObject
          }).map(obj => obj.id)

          if (formItem.referenceType === "hasMany") {
            relatedObjectsData[formItem.name] = objIds;
          } else if (formItem.referenceType === "hasManyThrough") {
            if (!formItem.referenceThrough) {
              console.error(formItem);
              throw new Error("Must specify referenceThrough")
            }
            relatedObjectsData[formItem.name] = objIds;
          } else {
            // This is a standards Salesforce "reference" type. In the
            // Nylas language it is a "belongsTo" `referenceType`
            let value = objIds[0]
            if (value === null || value === undefined) value = "";
            formPostData[formItem.name] = value;
          }
        } else {
          formPostData[formItem.name] = formItem.value;
        }
      })
    })

    return {
      formPostData,
      relatedObjectsData,
    };
  }
}

export default GeneratedFormToSalesforceAdapter
