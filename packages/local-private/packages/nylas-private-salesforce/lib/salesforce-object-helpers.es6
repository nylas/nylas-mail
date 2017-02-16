import _ from 'underscore'
import moment from 'moment';
import querystring from "querystring";
import {DatabaseStore} from 'nylas-exports'

import SalesforceEnv from './salesforce-env';
import SalesforceAPI from './salesforce-api';
import SalesforceObject from './models/salesforce-object'
import SalesforceActions from './salesforce-actions'

import * as mdHelpers from './metadata-helpers'

function _defaultFieldMapping() {
  return {
    Id: "id",
    Name: "name",
    LastModifiedDate: "updatedAt",
  };
}

function _fieldMapping() {
  return {
    User: _defaultFieldMapping(),
    Account: _defaultFieldMapping(),
    Opportunity: {
      Id: "id",
      Name: "name",
      AccountId: "relatedToId",
      LastModifiedDate: "updatedAt",
    },
    Contact: {
      Id: "id",
      Name: "name",
      Email: "identifier",
      AccountId: "relatedToId",
      LastModifiedDate: "updatedAt",
    },
    Lead: {
      Id: "id",
      Name: "name",
      Email: "identifier",
      LastModifiedDate: "updatedAt",
    },
    Case: {
      Id: "id",
      Subject: "name",
      CaseNumber: "identifier",
      AccountId: "relatedToId",
      LastModifiedDate: "updatedAt",
    },
    EmailMessage: {
      Id: "id",
      Subject: "identifier",
      LastModifiedDate: "updatedAt",
    },
    OpportunityContactRole: {
      Id: "id",
      ContactId: "identifier",
      OpportunityId: "relatedToId",
      LastModifiedDate: "updatedAt",
    },
  };
}

function _rawSalesforceDataAdapter(rawData, objectType) {
  if (!objectType) {
    console.error(rawData);
    throw new Error("Requested Salesforce object does not have a objectType");
  }

  let fieldMapping = _fieldMapping()[objectType];
  if (!fieldMapping) { fieldMapping = _defaultFieldMapping(); }

  let attrs = {};
  if (_.isFunction(fieldMapping)) {
    attrs = fieldMapping(rawData)
  } else {
    for (const sfKey of Object.keys(fieldMapping)) {
      const nyKey = fieldMapping[sfKey];
      let val;
      if (nyKey === "updatedAt") {
        val = moment(rawData[sfKey]).toDate();
      } else if (nyKey === "identifier") {
        if (sfKey === "Email") {
          val = (rawData[sfKey] || "").toLowerCase().trim();
        } else {
          val = rawData[sfKey];
        }
      } else {
        val = rawData[sfKey];
      }

      attrs[nyKey] = val;
    }
  }

  const obj = new SalesforceObject(Object.assign(attrs, {
    type: objectType,
    object: "SalesforceObject",
  }))

  return obj;
}

export function newBasicObjectsQuery(objectType, where = "", fields = []) {
  let fieldsStr = ""
  if (fields.length === 0) {
    let fieldMapping = _fieldMapping()[objectType];
    if (!fieldMapping) {
      fieldMapping = _defaultFieldMapping();
    }
    fieldsStr = Object.keys(fieldMapping).join(',');
  } else {
    fieldsStr = fields.join(',')
  }
  return querystring.stringify({q: `SELECT ${fieldsStr} FROM ${objectType} WHERE ${where}`});
}

export function loadBasicObjectsByField({objectType, where = {}, fields = []}) {
  if (!SalesforceEnv.isLoggedIn()) { return Promise.resolve(); }
  const wheres = []
  for (const field of Object.keys(where)) {
    wheres.push(`${field} = '${where[field]}'`)
  }
  const whereStr = wheres.join(" AND ");
  const query = newBasicObjectsQuery(objectType, whereStr, fields);
  return SalesforceAPI.makeRequest({path: `/query/?${query}`});
}

export function requestFullObjectFromAPI({objectType, objectId}) {
  return SalesforceAPI.makeRequest({
    path: `/sobjects/${objectType}/${objectId}`})
  .then((rawFullData) => {
    const obj = _rawSalesforceDataAdapter(rawFullData, objectType);
    // Note: The presence of rawData being filled is what makes this a
    // "full" object instead of a "basic" object.
    obj.rawData = rawFullData;
    return DatabaseStore.inTransaction(t => t.persistModel(obj).then(() => obj));
  })
  .catch((apiError = {}) => {
    if (apiError.statusCode !== 404) {
      // We don't re-throw since we've already reported the error and
      // don't want to take down the app at this point.
      SalesforceActions.reportError(apiError, {objectType, objectId})
      return null
    }
    return null
  });
}

// Attempts to fetch the given object from the Database. If the `rawData`
// field isn't populated or if the object doesn't exist, then we grab it
// from Salesforce
export function loadFullObject({objectType, objectId}) {
  return DatabaseStore.findBy(SalesforceObject, {id: objectId, type: objectType})
  .then((object = {}) => {
    if (object && object.rawData && _.size(object.rawData) > 0) { return object; }
    return requestFullObjectFromAPI({objectType, objectId});
  });
}

export function loadManuallyRelatedObjects(nylasObject) {
  const sObjects = _.values(mdHelpers.getManuallyRelatedObjects(nylasObject));
  return Promise.map(sObjects, (sObject) => {
    return loadFullObject({objectType: sObject.type, objectId: sObject.id});
  });
}


// Supports an array of objectTypes. This is useful when trying to look
// up an object that may be a reference to multiple things
export function loadBasicObject(objectTypes, objectId) {
  let types = objectTypes;
  if (_.isString(types)) types = [objectTypes];
  return DatabaseStore.findBy(SalesforceObject, {id: objectId, type: types})
  .then(object => {
    if (object) { return object; }
    return Promise.map(types, (type) => {
      return requestFullObjectFromAPI({objectType: type, objectId});
    }).then((objects = []) => {
      // There's only 1 ID, but we're searching across multiple object
      // types. There should only be 1 value returned.
      return _.compact(objects)[0]
    })
  });
}

export function upsertBasicObjects(data = {}) {
  const records = data.records || []
  if (records.length === 0) { return Promise.resolve([]); }
  try {
    const models = records.map((rawBasicData) => {
      const objectType = rawBasicData.attributes.type;
      return _rawSalesforceDataAdapter(rawBasicData, objectType)
    });

    if (models.length === 0) return Promise.resolve([]);

    return DatabaseStore.inTransaction(t => t.persistModels(models))
    .thenReturn(models)
  } catch (err) {
    SalesforceActions.reportError(err, {rawApiData: data})
    return Promise.reject(err)
  }
}
