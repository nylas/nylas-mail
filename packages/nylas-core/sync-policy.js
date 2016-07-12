class SyncPolicy {
  static defaultPolicy() {
    return {
      afterSync: 'idle',
      intervals: {
        active: 30 * 1000,
        inactive: 5 * 60 * 1000,
      },
      folderSyncOptions: {
        deepFolderScan: 10 * 60 * 1000,
      },
    };
  }
}

module.exports = SyncPolicy
