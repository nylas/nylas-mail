import NylasStore from 'nylas-store'
import ClearbitDataSource from './clearbit-data-source'
import {DatabaseStore, Utils} from 'nylas-exports'

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
      const data = this.getCache(contact);
      if (data.cacheDate) {
        return data
      }
      return {}
    }

    this.dataSource.find({email: contact.email}).then((data) => {
      if (data && data.email === contact.email) {
        this.saveDataToContact(contact, data)
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

  /**
   * We save the clearbit data to the contat object in the database.
   * This lets us load extra Clearbit data from other windows without
   * needing to call a very expensive API again.
   */
  saveDataToContact(contact, data) {
    return DatabaseStore.inTransaction((t) => {
      if (!contact.thirdPartyData) contact.thirdPartyData = {};
      contact.thirdPartyData.clearbit = data
      return t.persistModel(contact)
    })
  }

  deactivate() {
    // no op
  }
}
const store = new ParticipantProfileStore()
export default store
