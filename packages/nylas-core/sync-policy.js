class SyncPolicy {
  static defaultPolicy() {
    return {
      afterSync: 'idle',
      interval: 120 * 1000,
      folderSyncOptions: {
        deepFolderScan: 10 * 60 * 1000,
      },
    };
  }

  static activeUserPolicy() {
    return {
      afterSync: 'idle',
      interval: 30 * 1000,
      folderSyncOptions: {
        deepFolderScan: 5 * 60 * 1000,
      },
    };
  }
}

module.exports = SyncPolicy
