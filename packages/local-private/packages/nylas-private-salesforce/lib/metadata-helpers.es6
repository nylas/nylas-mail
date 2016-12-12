import {Utils} from 'nylas-exports'
import {PLUGIN_ID} from './salesforce-constants'

// When we attach metadata to Nylas objects we save SalesforceObjects
// according to the following schemas.
//
// thread.metadata = {
//   manuallyRelatedTo: {
//     "salesforceAccountId": {
//       id: "salesforceAccountId",
//       type: "Account",
//     }
//     "salesforceOpportunityId": {
//       id: "salesforceOpportunityId",
//       type: "Opportunity",
//     }
//     "salesforceCaseId": {
//       id: "salesforceCaseId",
//       type: "Case",
//     }
//   }
//
//   syncActivityTo: {
//     "salesforceOpportunityId": {
//       id: "salesforceOpportunityId",
//       type: "Opportunity",
//     }
//   }
// }
//
// message.metadata = {
//   clonedAs: {
//     "opportunityId": {
//       "taskId1": {
//         id: "taskId1",
//         type: "Task",
//         relatedToId: "opportunityId",
//       },
//       "emailMessageId": {
//         id: null,
//         errorCode: "FILE_TOO_LARGE"
//         errorMessage: "Body too large"
//         type: "EmailMessage",
//         relatedToId: "opportunityId",
//       },
//     },
//     "accountId": {
//       "taskId2": {
//         id: "taskId2",
//         type: "Task",
//         relatedToId: "accountId",
//       },
//       "emailMessageId2": {
//         id: "emailMessageId2",
//         type: "EmailMessage",
//         relatedToId: "accountId",
//       },
//     },
//   }
// }
//
// Schema before 2016-10-18 the schema used to look like:
// nylasObject.metadata = {
//   sObjects: {
//     "salesforceID1": {
//       id: "salesforceID1",
//       type: "Opportunity",
//     },
//     "salesforceID2": {
//       id: "salesforceID2",
//       type: "Account",
//     },
//     "salesforceID3": {
//       id: "salesforceID3",
//       type: "Task",
//       relatedToId: "salesforceID1"
//     },
//     "salesforceID4": {
//       id: "salesforceID4",
//       type: "EmailMessage",
//       relatedToId: "salesforceID1"
//     }
//   }
// }

function metadataClone(nylasObject) {
  return Utils.deepClone(nylasObject.metadataForPluginId(PLUGIN_ID) || {});
}

export function getManuallyRelatedObjects(nylasObject) {
  const metadata = metadataClone(nylasObject);
  return metadata.manuallyRelatedTo || {}
}

/**
 * Note we only store the id and type in the metadata.
 */
export function setManuallyRelatedObject(nylasObject, {id, type} = {}) {
  if (!id || !type) throw new Error("Must provide id and type of object");
  const metadata = metadataClone(nylasObject);
  const manuallyRelatedTo = metadata.manuallyRelatedTo || {};
  manuallyRelatedTo[id] = {id, type, name};
  metadata.manuallyRelatedTo = manuallyRelatedTo;
  nylasObject.applyPluginMetadata(PLUGIN_ID, metadata);
  return metadata
}

export function removeManuallyRelatedObject(nylasObject, {id} = {}) {
  if (!id) throw new Error("Must provide id");
  const metadata = metadataClone(nylasObject);
  const manuallyRelatedTo = metadata.manuallyRelatedTo || {};
  delete manuallyRelatedTo[id];
  metadata.manuallyRelatedTo = manuallyRelatedTo;
  nylasObject.applyPluginMetadata(PLUGIN_ID, metadata);
  return metadata
}


export function getSObjectsToSyncActivityTo(nylasObject) {
  const metadata = metadataClone(nylasObject);
  return metadata.syncActivityTo || {}
}

export function addActivitySyncSObject(nylasObject, {id, type} = {}) {
  if (!id || !type) throw new Error("Must provide id and type of object");
  const metadata = metadataClone(nylasObject);
  const syncActivityTo = metadata.syncActivityTo || {};
  syncActivityTo[id] = {id, type};
  metadata.syncActivityTo = syncActivityTo;
  nylasObject.applyPluginMetadata(PLUGIN_ID, metadata);
  return metadata
}

export function removeActivitySyncSObject(nylasObject, {id} = {}) {
  if (!id) throw new Error("Must provide id of object");
  const metadata = metadataClone(nylasObject);
  const syncActivityTo = metadata.syncActivityTo || {};
  delete syncActivityTo[id]
  metadata.syncActivityTo = syncActivityTo;
  nylasObject.applyPluginMetadata(PLUGIN_ID, metadata);
  return metadata
}


export function getClonedAsForSObject(nylasObject, relatedSObject = {}) {
  const metadata = metadataClone(nylasObject);
  const clonedAs = metadata.clonedAs || {}
  return clonedAs[relatedSObject.id] || {}
}

export function getClonedAs(nylasObject) {
  const metadata = metadataClone(nylasObject);
  return metadata.clonedAs || {}
}

// A Nylas Message may be replicated as a Salesforce Task on multiple
// Salesforce Opportunities. Given a Salesforce Task sObject, this will
// look through all opportunities until we find one with that Task id,
// then if so, return the corresponding opportunityId it's found under.
//
// This is useful when we discover that a Salesforce Task has been deleted
// and we need to cleanup references to that Task.
export function relatedIdForClonedSObject(nylasObject, sObject = {}) {
  const metadata = metadataClone(nylasObject);
  const clonedAs = metadata.clonedAs || {}
  for (const relatedToId of Object.keys(clonedAs)) {
    if (clonedAs[relatedToId][sObject.id]) return relatedToId;
  }
  return null;
}

export function addClonedSObject(nylasObject, relatedSObject = {}, {id, type, relatedToId} = {}) {
  if (!id || !type || !relatedToId) throw new Error("Must provide id, type, and relatedToId of object");
  if (!relatedSObject.id) throw new Error("Must provide a related sObject with an id")

  const metadata = metadataClone(nylasObject);
  const clonedAs = metadata.clonedAs || {};
  const clonedAsForObj = clonedAs[relatedSObject.id] || {};

  clonedAsForObj[id] = {id, type, relatedToId};
  clonedAs[relatedSObject.id] = clonedAsForObj;
  clonedAs[relatedSObject.id].type = relatedSObject.type;
  metadata.clonedAs = clonedAs;

  nylasObject.applyPluginMetadata(PLUGIN_ID, metadata);
  return metadata
}

export function removeClonedSObject(nylasObject, relatedSObject = {}, {id}) {
  if (!id) throw new Error("Must provide id of cloned object");
  if (!relatedSObject.id) throw new Error("Must provide a related sObject with an id")

  const metadata = metadataClone(nylasObject);
  const clonedAs = metadata.clonedAs || {};
  const clonedAsForObj = clonedAs[relatedSObject.id] || {};

  delete clonedAsForObj[id]
  clonedAs[relatedSObject.id] = clonedAsForObj;
  if (Object.keys(clonedAsForObj).length === 0) {
    delete clonedAs[relatedSObject.id]
  }
  metadata.clonedAs = clonedAs;

  nylasObject.applyPluginMetadata(PLUGIN_ID, metadata);
  return metadata
}
