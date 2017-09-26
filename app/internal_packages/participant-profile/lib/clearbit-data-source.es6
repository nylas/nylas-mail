import { MailspringAPIRequest } from 'mailspring-exports';
const { makeRequest } = MailspringAPIRequest;

const MAX_RETRY = 10;

export default class ClearbitDataSource {
  async find({ email, tryCount = 0 }) {
    if (tryCount >= MAX_RETRY) {
      return null;
    }
    const body = await makeRequest({
      server: 'identity',
      method: 'GET',
      path: `/api/info-for-email/${email}`,
    });
    return await this.parseResponse(body, email, tryCount);
  }

  parseResponse(body = {}, requestedEmail, tryCount = 0) {
    // This means it's in the process of fetching. Return null so we don't
    // cache and try again.
    return new Promise((resolve, reject) => {
      if (body.error) {
        if (body.error.type === 'queued') {
          setTimeout(() => {
            this.find({
              email: requestedEmail,
              tryCount: tryCount + 1,
            })
              .then(resolve)
              .catch(reject);
          }, 1000);
        } else {
          resolve(null);
        }
        return;
      }

      let person = body.person;

      // This means there was no data about the person available. Return a
      // valid, but empty object for us to cache. This can happen when we
      // have company data, but no personal data.
      if (!person) {
        person = { email: requestedEmail };
      }

      resolve({
        cacheDate: Date.now(),
        email: requestedEmail, // Used as checksum
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
      });
    });
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
}
