import {AccountStore, FolderSyncProgressStore, React} from 'nylas-exports';

export default class InitialSyncActivity extends React.Component {
  static displayName = 'InitialSyncActivity';

  constructor(props) {
    super(props);
    this.state = {
      syncState: FolderSyncProgressStore.getSyncState(),
    }
    this.mounted = false;
  }

  componentDidMount() {
    this.mounted = true;
    this.unsub = FolderSyncProgressStore.listen(this.onDataChanged)
  }

  componentWillUnmount() {
    this.unsub();
    this.mounted = false;
  }

  onDataChanged = () => {
    this.setState({syncState: FolderSyncProgressStore.getSyncState()});
  }

  renderFolderProgress(folderPath, {progress, busy}) {
    let status = 'complete';
    let progressLabel = '';

    if (busy) {
      status = 'busy';
      if (progress < 1) {
        progressLabel = `Scanning folder (${Math.round(progress * 100)}%)`;
      } else {
        progressLabel = `Indexing messages...`;
      }
    }

    return (
      <div className={`model-progress ${status}`} key={folderPath}>
        {folderPath} <span className="progress-label">{progressLabel}</span>
      </div>
    )
  }

  render() {
    if (FolderSyncProgressStore.isSyncComplete()) {
      return false;
    }


    let maxHeight = 0;
    let accounts = Object.entries(this.state.syncState).map(([accountId, accountSyncState]) => {
      const account = AccountStore.accountForId(accountId);
      if (!account) {
        return false;
      }

      let folderStates = Object.entries(accountSyncState).map(([folderPath, folderState]) => {
        return this.renderFolderProgress(folderPath, folderState)
      })

      if (folderStates.length === 0) {
        folderStates = <div><br />Gathering folders...</div>
      }

      // A row for the account email address plus a row for each folder state,
      const numRows = 1 + (folderStates.length || 1)
      maxHeight += 50 * numRows;

      return (
        <div className="account" key={accountId}>
          <h2>{account.emailAddress}</h2>
          {folderStates}
        </div>
      )
    });

    if (accounts.length === 0) {
      accounts = <div><br />Looking for accounts...</div>
    }

    return (
      <div
        className="account-detail-area"
        key="expanded-sync-state"
        style={{maxHeight: `${maxHeight + 500}px`}}
      >
        {accounts}
      </div>
    )
  }

}
