import _ from 'underscore'
import moment from 'moment-timezone'
import {
  AccountStore,
  NylasAPI,
  NylasAPIRequest,
  FolderSyncProgressStore,
} from 'nylas-exports'
import RefreshingJSONCache from './refreshing-json-cache'

// Stores contact rankings
class ContactRankingsCache extends RefreshingJSONCache {
  constructor(accountId) {
    super({
      key: `ContactRankingsFor${accountId}`,
      version: 1,
      refreshInterval: moment.duration(60, 'seconds').asMilliseconds(),
      maxRefreshInterval: moment.duration(24, 'hours').asMilliseconds(),
    })
    this._accountId = accountId
  }

  _nextRefreshInterval() {
    // For the first 15 minutes, refresh roughly once every minute so that the
    // experience of composing drafts during initial is less annoying.
    const initialLimit = (60 * 1000) + 15;
    if (this.refreshInterval < initialLimit) {
      return this.refreshInterval + 1;
    }
    // After the first 15 minutes, refresh twice as long each time up to the max.
    return Math.min(this.refreshInterval * 2, this.maxRefreshInterval);
  }

  fetchData = (callback) => {
    if (NylasEnv.inSpecMode()) return

    const request = new NylasAPIRequest({
      api: NylasAPI,
      options: {
        accountId: this._accountId,
        path: "/contacts/rankings",
      },
    })

    request.run()
    .then((json) => {
      if (!json || !(json instanceof Array)) return

      // Convert rankings into the format needed for quick lookup
      const rankings = {}
      for (const [email, rank] of json) {
        rankings[email.toLowerCase()] = rank
      }
      callback(rankings)

      this.refreshInterval = this._nextRefreshInterval();
    })
    .catch((err) => {
      console.warn(`Request for Contact Rankings failed for
                    account ${this._accountId}. ${err}`)
    })
  }
}

class ContactRankingsCacheManager {
  constructor() {
    this.accountCaches = {};
    this.unsubscribers = [];
    this.onAccountsChanged = _.debounce(this.onAccountsChanged, 100);
  }

  activate() {
    this.onAccountsChanged();
    this.unsubscribers = [AccountStore.listen(this.onAccountsChanged)];
  }

  deactivate() {
    this.unsubscribers.forEach(unsub => unsub());
  }

  onAccountsChanged = async () => {
    const previousIDs = Object.keys(this.accountCaches);
    const latestIDs = AccountStore.accounts().map(a => a.id);
    if (_.isEqual(previousIDs, latestIDs)) {
      return;
    }

    const newIDs = _.difference(latestIDs, previousIDs);
    const removedIDs = _.difference(previousIDs, latestIDs);

    console.log(`ContactRankingsCache: Updating contact rankings; added = ${latestIDs}, removed = ${removedIDs}`);

    for (const newID of newIDs) {
      // Wait until the account has started syncing before trying to fetch
      // contact rankings
      await FolderSyncProgressStore.whenCategoryListSynced(newID)
      this.accountCaches[newID] = new ContactRankingsCache(newID);
      this.accountCaches[newID].start();
    }

    for (const removedID of removedIDs) {
      if (this.accountCaches[removedID]) {
        this.accountCaches[removedID].end();
        this.accountCaches[removedID] = null;
      }
    }
  }
}

export default new ContactRankingsCacheManager();
