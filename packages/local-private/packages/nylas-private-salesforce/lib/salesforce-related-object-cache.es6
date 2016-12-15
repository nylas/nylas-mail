import _ from 'underscore'
import { Rx, AccountStore, DatabaseStore } from 'nylas-exports'
import SalesforceObject from './models/salesforce-object'

class SalesforceRelatedObjectCache {

  constructor() {
    this._unsubscribers = []
    this._observers = {}
    this._sObjectsByEmail = new Map();
    this._changes = []
    this._updateCache = _.debounce(this._updateCache, 100);
  }

  activate() {
    this._initializeCache()
    this._unsubscribers = [
      DatabaseStore.listen(this._onDataChanged),
    ]
  }

  directlyRelatedSObjectsForThread(thread) {
    const objs = {}
    const myEmails = AccountStore.emailAddresses().map((em) => em.toLowerCase())
    for (const participant of thread.participants) {
      if (myEmails.includes(participant.email.toLowerCase())) continue;
      Object.assign(objs, this.directlyRelatedSObjectsByEmail(participant.email))
    }
    return objs;
  }

  directlyRelatedSObjectsByEmail(rawEmail) {
    const email = rawEmail.trim().toLowerCase()
    return this._sObjectsByEmail.get(email) || {}
  }

  observeDirectlyRelatedSObjectsByEmail(email) {
    return Rx.Observable.create((observer) => {
      if (!this._observers[email]) this._observers[email] = [];
      this._observers[email].push({
        observer: observer,
        observerType: "email",
      })
      observer.onNext(this.directlyRelatedSObjectsByEmail(email))
      return Rx.Disposable.create(() => {
        if (!this._observers[email]) return;
        this._observers[email] = this._observers[email].filter(obs => obs.observer !== observer)
        if (this._observers[email].length === 0) {
          delete this._observers[email]
        }
      })
    })
  }

  observeDirectlyRelatedSObjectsForThread(thread) {
    return Rx.Observable.create((observer) => {
      const myEmails = AccountStore.emailAddresses().map((em) => em.toLowerCase())
      observer.alsoFireFor = thread.participants
      for (const participant of thread.participants) {
        if (myEmails.includes(participant.email.toLowerCase())) continue;
        if (!this._observers[participant.email]) {
          this._observers[participant.email] = []
        }
        this._observers[participant.email].push({
          observer: observer,
          observerType: "thread",
          thread: thread,
        })
      }

      observer.onNext(this.directlyRelatedSObjectsForThread(thread))

      return Rx.Disposable.create(() => {
        for (const participant of thread.participants) {
          if (!this._observers[participant.email]) {
            continue
          }
          this._observers[participant.email] = this._observers[participant.email].filter(obs => obs.observer !== observer)
          if (this._observers[participant.email].length === 0) {
            delete this._observers[participant.email]
          }
        }
      })
    })
  }

  _initializeCache() {
    return DatabaseStore.findAll(SalesforceObject, {type: "Contact"})
    .then(this._updateContacts)
  }

  _onDataChanged = (change) => {
    if (change.objectClass !== SalesforceObject.name) return
    this._changes = this._changes.concat(change);
    this._updateCache()
  }

  _getBasicObject = (sObject) => {
    const objForCache = Object.assign({}, sObject);
    delete objForCache.rawData;
    objForCache.id = sObject.id;
    return objForCache
  }

  _changeObjectInCache = (sObject, rawEmail, changeType) => {
    if (!rawEmail || !sObject) return
    const email = rawEmail.trim().toLowerCase()
    let relatedObjects = this._sObjectsByEmail.get(email)
    const objectToUpdate = this._getBasicObject(sObject)
    if (!relatedObjects) relatedObjects = {}
    if (changeType === "unpersist") {
      delete relatedObjects[sObject.id]
    } else {
      relatedObjects[sObject.id] = objectToUpdate
    }
    this._sObjectsByEmail.set(email, relatedObjects)
    if (this._observers[email]) {
      for (const {observer, observerType, thread} of this._observers[email]) {
        if (observerType === "email") {
          observer.onNext(this.directlyRelatedSObjectsByEmail(email))
        } else if (observerType === "thread") {
          observer.onNext(this.directlyRelatedSObjectsForThread(thread))
        }
      }
    }
  }

  // Contact: Find accounts and opportunities using email from contacts
  // and add to cache. This is optimized for many contacts at once since
  // we rebuild the cache on every launch.
  _updateContacts = (contacts = [], changeType) => {
    if (contacts.length === 0) return Promise.resolve()
    const contactIds = _.compact(_.pluck(contacts, "id"))
    const relatedToIds = _.compact(_.pluck(contacts, "relatedToId"))

    const objectsToUpdate = {}
    for (const contact of contacts) {
      objectsToUpdate[contact.identifier] = [contact]
    }

    if (relatedToIds.length === 0) {
      for (const email of Object.keys(objectsToUpdate)) {
        for (const sObject of objectsToUpdate[email]) {
          this._changeObjectInCache(sObject, email, changeType)
        }
      }
      return Promise.resolve()
    }
    return DatabaseStore.findAll(SalesforceObject, {
      type: "Account",
      id: relatedToIds,
    })
    .then((accounts) => {
      const accById = _.groupBy(accounts, "id");
      for (const contact of contacts) {
        const account = (accById[contact.relatedToId] || [])[0]
        if (!account) continue;
        objectsToUpdate[contact.identifier].push(account)
      }
      return Promise.resolve()
    })
    .then(() => {
      if (contactIds.length === 0) return {opportunityContactRoles: []}
      return DatabaseStore.findAll(SalesforceObject, {
        type: "OpportunityContactRole",
        identifier: contactIds,
      })
    })
    .then((opportunityContactRoles = []) => {
      const oppIds = _.compact(_.pluck(opportunityContactRoles, "relatedToId"));
      if (oppIds.length === 0) return {opportunities: [], opportunityContactRoles}
      return DatabaseStore.findAll(SalesforceObject, {
        type: "Opportunity",
        id: oppIds,
      }).then((opportunities = []) => {
        return {opportunities, opportunityContactRoles}
      })
    })
    .then(({opportunities, opportunityContactRoles}) => {
      const roleByCid = _.groupBy(opportunityContactRoles, "identifier");
      const oppById = _.groupBy(opportunities, "id")

      for (const contact of contacts) {
        const role = (roleByCid[contact.id] || [])[0]
        if (!role) continue;
        const opp = (oppById[role.relatedToId] || [])[0];
        if (!opp) continue;
        objectsToUpdate[contact.identifier].push(opp)
      }
    })
    .then(() => {
      for (const email of Object.keys(objectsToUpdate)) {
        for (const sObject of objectsToUpdate[email]) {
          this._changeObjectInCache(sObject, email, changeType)
        }
      }
    })
  }

  // Account: Add accounts to cache using email from contact
  _updateAccounts = (accounts = [], changeType) => {
    if (accounts.length === 0) return Promise.resolve();
    const aids = _.pluck(accounts, "id");
    return DatabaseStore.findAll(SalesforceObject, {
      type: "Contact",
      relatedToId: aids,
    }).then((contacts) => {
      const accById = _.groupBy(accounts, "id");
      for (const contact of contacts) {
        const account = (accById[contact.relatedToId] || [])[0]
        this._changeObjectInCache(account, contact.identifier, changeType)
      }
    })
  }

  // Opportunity: Add opportunities to cache using email from contact
  _updateOpportunities = (opportunities = [], changeType) => {
    if (opportunities.length === 0) return Promise.resolve();
    const oids = _.pluck(opportunities, "id");
    return DatabaseStore.findAll(SalesforceObject, {
      type: "OpportunityContactRole",
      relatedToId: oids,
    })
    .then((opportunityContactRoles) => {
      const contactIds = _.pluck(opportunityContactRoles, "identifier");
      const roleByCid = _.groupBy(opportunityContactRoles, "identifier");
      const oppById = _.groupBy(opportunities, "id");
      return DatabaseStore.findAll(SalesforceObject, {
        type: "Contact",
        id: contactIds,
      }).then((contacts) => {
        for (const contact of contacts) {
          const role = (roleByCid[contact.id] || [])[0]
          if (!role) continue;
          const opp = (oppById[role.relatedToId] || [])[0];
          if (!opp) continue;
          this._changeObjectInCache(opp, contact.identifier, changeType)
        }
      })
    })
  }

  // OpportunityContactRole: Add opportunities to cache using email from contact
  _updateOpportunityContactRoles = (opportunityContactRoles = [], changeType) => {
    if (opportunityContactRoles.length === 0) return Promise.resolve();
    const cids = _.pluck(opportunityContactRoles, "identifier");
    const roleByCid = _.groupBy(opportunityContactRoles, "identifier");
    const oppIds = _.pluck(opportunityContactRoles, "relatedToId")
    return DatabaseStore.findAll(SalesforceObject, {
      type: "Contact",
      id: cids,
    })
    .then((contacts) => {
      return DatabaseStore.findAll(SalesforceObject, {
        type: "Opportunity",
        id: oppIds,
      })
      .then((opportunities) => {
        const oppById = _.groupBy(opportunities, "id");
        for (const contact of contacts) {
          const role = (roleByCid[contact.id] || [])[0]
          if (!role) continue;
          const opp = (oppById[role.relatedToId] || [])[0];
          if (!opp) continue;
          this._changeObjectInCache(opp, contact.identifier, changeType)
        }
      })
    })
  }

  _updateLeads = (leads = [], changeType) => {
    if (leads.length === 0) return Promise.resolve()
    for (const lead of leads) {
      this._changeObjectInCache(lead, lead.identifier, changeType)
    }
    return Promise.resolve();
  }

  /*
  The cache is keyed by email and the values represent the related Salesforce
  objects (opportunities and accounts).

  This method id debounced and loads the latest from _changes.

  this._sObjectsByEmail = {
    "jackie@nylas.com": {
      "ACCOUNT_ID": {
        name: "",
        type: "",
        identifier: "",
        relatedToId: "",
      },
      "OPPORTUNITY_ID": {
        ...
      }
    }
  }
  */
  _updateCache = () => {
    const changes = this._changes;
    this._changes = [];
    const changeByType = _.groupBy(changes, "type");
    for (const changeType of Object.keys(changeByType)) {
      const sObjects = _.flatten(changeByType[changeType].map(c => c.objects));
      if (sObjects.length === 0) continue;
      const objsByType = _.groupBy(sObjects, "type");
      Promise.all([
        this._updateLeads(objsByType.Lead, changeType),
        this._updateContacts(objsByType.Contact, changeType),
        this._updateAccounts(objsByType.Account, changeType),
        this._updateOpportunities(objsByType.Opportunity, changeType),
        this._updateOpportunityContactRoles(objsByType.OpportunityContactRole, changeType),
      ])
    }
  }

  deactivate() {
    this._unsubscribers.forEach((usub) => usub())
  }
}


export default new SalesforceRelatedObjectCache()
