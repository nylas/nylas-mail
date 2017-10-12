import { MailspringAPIRequest, Utils } from 'mailspring-exports';
const { makeRequest } = MailspringAPIRequest;

const CACHE_SIZE = 200;
const CACHE_INDEX_KEY = 'pp-cache-v3-keys';
const CACHE_KEY_PREFIX = 'pp-cache-v3-';

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

    if (!body.person) {
      body.person = { email };
    }
    if (!body.company) {
      body.company = {};
    }

    this.setCache(email, body);
    return body;
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
