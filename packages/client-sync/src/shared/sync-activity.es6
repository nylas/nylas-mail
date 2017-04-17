class SyncActivity {
  constructor() {
    // Keyed by accountId, each value is structured like
    // {
    //   time: 1490293620249,
    //   activity: (whatever was passed in, usually a string)
    // }
    this._lastActivityByAccountId = {}
  }

  reportSyncActivity = (accountId, activity) => {
    if (!this._lastActivityByAccountId[accountId]) {
      this._lastActivityByAccountId[accountId] = {};
    }
    const lastActivity = this._lastActivityByAccountId[accountId]
    lastActivity.time = Date.now();
    lastActivity.activity = activity;
  }

  getLastSyncActivityForAccount = (accountId) => {
    return this._lastActivityByAccountId[accountId] || {}
  }

  getLastSyncActivity = () => {
    return this._lastActivityByAccountId
  }
}

export default new SyncActivity()
