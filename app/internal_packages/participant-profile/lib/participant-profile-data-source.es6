import { MailspringAPIRequest, Utils } from 'mailspring-exports';
const { makeRequest } = MailspringAPIRequest;

const CACHE_SIZE = 200;
const CACHE_INDEX_KEY = 'pp-cache-keys';
const CACHE_KEY_PREFIX = 'pp-cache-';

class ParticipantProfileDataSource {
  constructor() {
    try {
      this._cacheIndex = JSON.parse(window.localStorage.getItem(CACHE_INDEX_KEY) || `[]`);
    } catch (err) {
      this._cacheIndex = [];
    }
  }

  async find(email) {
    if (!email || Utils.likelyNonHumanEmail(email)) {
      return {};
    }

    const data = this.getCache(email);
    if (data) {
      return data;
    }

    let body = null;

    try {
      body = await makeRequest({
        server: 'identity',
        method: 'GET',
        path: `/api/info-for-email-v2/${email}`,
      });
    } catch (err) {
      // we don't care about errors returned by this clearbit proxy
      return {};
    }

    let person = (body || {}).person;

    // This means there was no data about the person available. Return a
    // valid, but empty object for us to cache. This can happen when we
    // have company data, but no personal data.
    if (!person) {
      person = { email };
    }

    const result = {
      cacheDate: Date.now(),
      email: email, // Used as checksum
      bio:
        person.bio ||
        (person.twitter && person.twitter.bio) ||
        (person.aboutme && person.aboutme.bio),
      location: person.location || (person.geo && person.geo.city) || null,
      currentTitle: person.employment && person.employment.title,
      currentEmployer: person.employment && person.employment.name,
      profilePhotoUrl: person.avatar,
      rawClearbitData: body,
      socialProfiles: this._socialProfiles(person),
    };

    this.setCache(email, result);
    return result;
  }

  _socialProfiles(person = {}) {
    const profiles = {};

    if (((person.twitter && person.twitter.handle) || '').length > 0) {
      profiles.twitter = {
        handle: person.twitter.handle,
        url: `https://twitter.com/${person.twitter.handle}`,
      };
    }
    if (((person.facebook && person.facebook.handle) || '').length > 0) {
      profiles.facebook = {
        handle: person.facebook.handle,
        url: `https://facebook.com/${person.facebook.handle}`,
      };
    }
    if (((person.linkedin && person.linkedin.handle) || '').length > 0) {
      profiles.linkedin = {
        handle: person.linkedin.handle,
        url: `https://linkedin.com/${person.linkedin.handle}`,
      };
    }
    return profiles;
  }

  // LocalStorage Retrieval / Saving

  hasCache(email) {
    return localStorage.getItem(`${CACHE_KEY_PREFIX}${email}`) !== null;
  }

  getCache(email) {
    const raw = localStorage.getItem(`${CACHE_KEY_PREFIX}${email}`);
    if (!raw) {
      return null;
    }
    try {
      return JSON.parse(raw);
    } catch (err) {
      return null;
    }
  }

  setCache(email, value) {
    localStorage.setItem(`${CACHE_KEY_PREFIX}${email}`, JSON.stringify(value));
    const updatedIndex = this._cacheIndex.filter(e => e !== email);
    updatedIndex.push(email);

    if (updatedIndex.length > CACHE_SIZE) {
      const oldestKey = updatedIndex.shift();
      localStorage.removeItem(`${CACHE_KEY_PREFIX}${oldestKey}`);
    }

    localStorage.setItem(CACHE_INDEX_KEY, JSON.stringify(updatedIndex));
    this._cacheIndex = updatedIndex;
  }
}

export default new ParticipantProfileDataSource();
