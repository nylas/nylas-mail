import _ from 'underscore';
import _str from 'underscore.string';
import classNames from 'classnames';
import {Actions, AccountStore, NylasSyncStatusStore, React} from 'nylas-exports';

export default class InitialSyncActivity extends React.Component {
  static displayName = 'InitialSyncActivity';

  constructor(props) {
    super(props);
    this.state = {
      isExpanded: false,
      syncState: NylasSyncStatusStore.getSyncState(),
      syncProgress: NylasSyncStatusStore.getSyncProgress(),
    }
    this.mounted = false;
  }

  componentDidMount() {
    this.mounted = true;
    this.unsubs = [
      NylasSyncStatusStore.listen(this.onDataChanged),
      Actions.expandInitialSyncState.listen(this.showExpandedState),
    ]
  }

  componentWillUnmount() {
    if (this.unsubs) {
      this.unsubs.forEach((unsub) => unsub())
    }
    this.mounted = false;
  }

  onDataChanged = () => {
    const syncState = NylasSyncStatusStore.getSyncState()
    const syncProgress = NylasSyncStatusStore.getSyncProgress()
    this.setState({syncState, syncProgress});
  }

  hideExpandedState = () => {
    this.setState({isExpanded: false});
  }

  showExpandedState = () => {
    if (!this.state.isExpanded) {
      this.setState({isExpanded: true});
    } else {
      this.setState({blink: true});
      setTimeout(() => {
        if (this.mounted) {
          this.setState({blink: false});
        }
      }, 1000)
    }
  }

  renderExpandedSyncState() {
    let maxHeight = 0;
    let accounts = _.map(this.state.syncState, (accountSyncState, accountId) => {
      const account = _.findWhere(AccountStore.accounts(), {id: accountId});
      if (!account) {
        return false;
      }

      const {folderSyncProgress} = accountSyncState
      let folderStates = _.map(folderSyncProgress, ({progress}, name) => {
        return this.renderFolderProgress(name, progress)
      })

      if (folderStates.length === 0) {
        folderStates = <div><br />Gathering folders...</div>
      }

      // A row for the account email address plus a row for each folder state,
      const numRows = 1 + (folderStates.length || 1)
      maxHeight += 50 * numRows;

      return (
        <div className="account inner" key={accountId}>
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
        <a className="close-expanded" onClick={this.hideExpandedState}>Hide</a>
      </div>
    )
  }

  renderFolderProgress(name, progress) {
    let status = 'busy';
    if (progress === 1) {
      status = 'complete';
    }

    return (
      <div className={`model-progress ${status}`} key={name}>
        <h3>{_str.titleize(name)}:</h3>
        {this.renderProgressBar(progress)}
        <div className="amount">{`${_str.numberFormat(progress * 100, 2) || '0.00'}%`}</div>
      </div>
    )
  }

  renderProgressBar(progress) {
    return (
      <div className="progress-track">
        <div className="progress" style={{width: `${(progress || 0) * 100}%`}} />
      </div>
    )
  }

  render() {
    if (!AccountStore.accountsAreSyncing()) {
      return false;
    }

    const {syncProgress: {progress}} = this.state
    if (progress === 1) {
      return false;
    }

    const classSet = classNames({
      'item': true,
      'expanded-sync': this.state.isExpanded,
      'blink': this.state.blink,
    });

    return (
      <div
        className={classSet}
        key="initial-sync"
        onClick={() => (this.setState({isExpanded: !this.state.isExpanded}))}
      >
        {this.renderProgressBar(progress)}
        <div className="inner">Syncing your mailbox&hellip;</div>
        {this.state.isExpanded ? this.renderExpandedSyncState() : false}
      </div>
    )
  }
}
