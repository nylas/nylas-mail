/** @babel */
import NylasStore from 'nylas-store'
import ClearbitDataSource from './clearbit-data-source'
import {Utils} from 'nylas-exports'

// TODO: Back with Metadata
const contactCache = {}
const CACHE_SIZE = 100
const contactCacheKeyIndex = []

class ParticipantProfileStore extends NylasStore {
  activate() {
    this.cacheExpiry = 1000 * 60 * 60 * 24 // 1 day
    this.dataSource = new ClearbitDataSource()
  }

  dataForContact(contact) {
    if (!contact) {
      return {}
    }

    if (Utils.likelyNonHumanEmail(contact.email)) {
      return {}
    }

    if (this.inCache(contact)) {
      return this.getCache(contact)
    }

    this.dataSource.find({email: contact.email}).then((data) => {
      if (data.email === contact.email) {
        this.setCache(contact, data);
        this.trigger()
      }
    })
    return {}
  }

  // TODO: Back by metadata.
  getCache(contact) {
    return contactCache[contact.email]
  }

  inCache(contact) {
    const cache = contactCache[contact.email]
    if (!cache) { return false }
    if (!cache.cacheDate || Date.now() - cache.cacheDate > this.cacheExpiry) {
      return false
    }
    return true
  }

  setCache(contact, value) {
    contactCache[contact.email] = value
    contactCacheKeyIndex.push(contact.email)
    if (contactCacheKeyIndex.length > CACHE_SIZE) {
      delete contactCache[contactCacheKeyIndex.shift()]
    }
    return value
  }

  deactivate() {
    // no op
  }
}
module.exports = new ParticipantProfileStore()
