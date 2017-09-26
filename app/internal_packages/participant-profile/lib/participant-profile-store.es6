import { Utils } from 'mailspring-exports';
import NylasStore from 'nylas-store';
import ClearbitDataSource from './clearbit-data-source';

const contactCache = {};
const CACHE_SIZE = 100;
const contactCacheKeyIndex = [];

// TODO: Put cache into localstorage

class ParticipantProfileStore extends NylasStore {
  constructor() {
    super();
    this.cacheExpiry = 1000 * 60 * 60 * 24; // 1 day
    this.dataSource = new ClearbitDataSource();
  }

  activate() {}

  deactivate() {
    // no op
  }

  dataForContact(contact) {
    if (!contact) {
      return {};
    }

    if (Utils.likelyNonHumanEmail(contact.email)) {
      return {};
    }

    if (this.inCache(contact)) {
      const data = this.getCache(contact);
      if (data.cacheDate) {
        return data;
      }
      return {};
    }

    this.dataSource
      .find({ email: contact.email })
      .then(data => {
        if (data && data.email === contact.email) {
          this.setCache(contact, data);
          this.trigger();
        }
      })
      .catch((err = {}) => {
        if (err.statusCode !== 404) {
          throw err;
        }
      });
    return {};
  }

  getCache(contact) {
    return contactCache[contact.email];
  }

  inCache(contact) {
    const cache = contactCache[contact.email];
    if (!cache) {
      return false;
    }
    if (!cache.cacheDate || Date.now() - cache.cacheDate > this.cacheExpiry) {
      return false;
    }
    return true;
  }

  setCache(contact, value) {
    contactCache[contact.email] = value;
    contactCacheKeyIndex.push(contact.email);
    if (contactCacheKeyIndex.length > CACHE_SIZE) {
      delete contactCache[contactCacheKeyIndex.shift()];
    }
    return value;
  }
}

export default new ParticipantProfileStore();
