import _ from 'underscore'

import {
  Rx,
  DatabaseStore,
  Thread,
} from 'nylas-exports'
import * as mdHelpers from './metadata-helpers'
import SalesforceRelatedObjectCache from './salesforce-related-object-cache'

export function getUniqueRelatedSObjects(directObjects, manualObjects) {
  const sObjects = []
  const addedObjectIds = []
  for (const obj of directObjects.concat(manualObjects)) {
    if (!addedObjectIds.includes(obj.id)) {
      sObjects.push(obj)
      addedObjectIds.push(obj.id)
    }
  }
  return sObjects
}

export function relatedSObjectsForThread(thread) {
  const direct = _.values(SalesforceRelatedObjectCache.directlyRelatedSObjectsForThread(thread))
  const manual = _.values(mdHelpers.getManuallyRelatedObjects(thread))
  if (!direct) return []
  return getUniqueRelatedSObjects(direct, manual)
}

export function observeRelatedSObjectsForThread(thread) {
  const directSource = SalesforceRelatedObjectCache.observeDirectlyRelatedSObjectsForThread(thread)
  const manualSource = Rx.Observable.fromQuery(DatabaseStore.find(Thread, thread.id))
  return Rx.Observable.combineLatest(directSource, manualSource).map((objects) => {
    const [directObjectMap, observedThread] = objects
    const directObjects = _.values(directObjectMap);
    let manualObjects = _.values(mdHelpers.getManuallyRelatedObjects(observedThread))
    manualObjects = manualObjects.map((manualObject) => {
      manualObject.manuallyRelated = true
      return manualObject
    })
    return getUniqueRelatedSObjects(directObjects, manualObjects)
  })
}
