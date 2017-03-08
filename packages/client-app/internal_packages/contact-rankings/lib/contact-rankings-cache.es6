import {
  NylasAPI,
  NylasAPIRequest,
} from 'nylas-exports'
import RefreshingJSONCache from './refreshing-json-cache'


// Stores contact rankings
class ContactRankingsCache extends RefreshingJSONCache {
  constructor(accountId) {
    super({
      key: `ContactRankingsFor${accountId}`,
      version: 1,
      refreshInterval: 60 * 60 * 1000 * 24, // one day
    })
    this._accountId = accountId
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
    })
    .catch((err) => {
      console.warn(`Request for Contact Rankings failed for
                    account ${this._accountId}. ${err}`)
    })
  }
}

export default ContactRankingsCache
