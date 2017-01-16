import _ from 'underscore';
import _str from 'underscore.string';
import {Utils, AccountStore, NylasSyncStatusStore, React} from 'nylas-exports';

const MONTH_SHORT_FORMATS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
  'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export default class InitialSyncActivity extends React.Component {
  static displayName = 'InitialSyncActivity';

  constructor(props) {
    super(props);
    this.state = {
      syncState: NylasSyncStatusStore.getSyncState(),
    }
    this.mounted = false;
  }

  componentDidMount() {
    this.mounted = true;
    this.unsub = NylasSyncStatusStore.listen(this.onDataChanged)
  }

  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.isEqualReact(nextProps, this.props) ||
      !Utils.isEqualReact(nextState, this.state);
  }

  componentWillUnmount() {
    this.unsub();
    this.mounted = false;
  }

  onDataChanged = () => {
    const syncState = Utils.deepClone(NylasSyncStatusStore.getSyncState())
    this.setState({syncState});
  }

  renderFolderProgress(name, progress, oldestProcessedDate) {
    let status = 'busy';
    let progressLabel = 'In Progress'
    let syncedThrough = 'Syncing this past month';
    if (progress === 1) {
      status = 'complete';
      progressLabel = '';
      syncedThrough = 'Up to date'
    } else {
      let month = oldestProcessedDate.getMonth();
      let year = oldestProcessedDate.getFullYear();
      const currentDate = new Date();
      if (month !== currentDate.getMonth() || year !== currentDate.getFullYear()) {
        // We're currently syncing in `month`, which mean's we've synced through all
        // of the month *after* it.
        month++;
        if (month === 12) {
          month = 0;
          year++;
        }
        syncedThrough = `Synced through ${MONTH_SHORT_FORMATS[month]} ${year}`;
      }
    }

    return (
      <div className={`model-progress ${status}`} key={name} title={syncedThrough}>
        {_str.titleize(name)} <span className="progress-label">{progressLabel}</span>
      </div>
    )
  }

  render() {
    if (!AccountStore.accountsAreSyncing() || NylasSyncStatusStore.isSyncComplete()) {
      return false;
    }

    let maxHeight = 0;
    let accounts = _.map(this.state.syncState, (accountSyncState, accountId) => {
      const account = _.findWhere(AccountStore.accounts(), {id: accountId});
      if (!account) {
        return false;
      }

      const {folderSyncProgress} = accountSyncState
      let folderStates = _.map(folderSyncProgress, ({progress, oldestProcessedDate}, name) => {
        return this.renderFolderProgress(name, progress, oldestProcessedDate)
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
