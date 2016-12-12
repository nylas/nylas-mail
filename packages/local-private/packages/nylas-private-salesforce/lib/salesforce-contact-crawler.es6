import _ from 'underscore'

import {
  Contact,
  DatabaseStore,
  Utils,
} from 'nylas-exports'
import SalesforceEnv from './salesforce-env'
import SalesforceActions from './salesforce-actions'
import SalesforceObject from './models/salesforce-object'


// Check for new contacts once a day
const REFRESH_INTERVAL = 1000 * 60 * 60 * 24
const JSOB_BLOB_KEY = "SalesforceContactCrawler"

class SalesforceContactCrawler {

  activate() {
    this._unsubscribe = SalesforceActions.syncSalesforce.listen(this._run)
    this._interval = setInterval(this._run, REFRESH_INTERVAL)
    setTimeout(this._run, 3000)

    this._sContacts = []
    this._domains = []
    this._suggestedContacts = []
  }

  deactivate() {
    this._unsubscribe()
    clearInterval(this._interval)
  }

  _run = () => {
    if (!SalesforceEnv.isLoggedIn()) return
    DatabaseStore.findAll(SalesforceObject, {
      type: "Contact",
    })
    .then((sContacts) => {
      this._sContacts = sContacts
      for (const sContact of sContacts) {
        this._addToDomains(sContact.identifier)
      }
      return Promise.resolve()
    })
    .then(() => {
      return DatabaseStore.findAll(Contact)
    })
    .then((contacts) => {
      for (const contact of contacts) {
        this._addToSuggestedContacts(contact)
      }
      return Promise.resolve()
    })
    .then(() => {
      DatabaseStore.inTransaction((t) => {
        return t.persistJSONBlob(JSOB_BLOB_KEY, this._suggestedContacts)
      })
    })
  }

  _getDomain(email) {
    return _.last(email.toLowerCase().trim().split("@"))
  }

  // Check if domain is probably a company (i.e., not Gmail) and unique
  _addToDomains(email) {
    const domain = this._getDomain(email)
    if (domain.length > 0 &&
      !Utils.emailHasCommonDomain(email) &&
      !this._domains.includes(domain)) {
      this._domains.push(domain)
    }
  }

  // Check if contact is real person and is from same company as a Salesforce contact
  _addToSuggestedContacts(contact) {
    if (contact.email &&
      !Utils.likelyNonHumanEmail(contact.email) &&
      this._domains.includes(this._getDomain(contact.email))) {
      this._suggestedContacts.push(contact)
    }
  }

}

export default new SalesforceContactCrawler()

