import _ from 'underscore';
import _str from 'underscore.string';
import classNames from 'classnames';
import {AccountStore, NylasSyncStatusStore, React} from 'nylas-exports';

export default class InitialSyncActivity extends React.Component {
  static displayName = 'InitialSyncActivity';

  constructor(props) {
    super(props);
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this.unsubscribe = NylasSyncStatusStore.listen(this.onDataChanged);
  }

  componentWillUnmount() {
    if (this.unsubscribe) {
      this.unsubscribe();
    }
  }

  onDataChanged = () => {
    this.setState(this.getStateFromStores());
  }

  getStateFromStores() {
    return {
      syncState: NylasSyncStatusStore.state(),
    };
  }

  /*
    Iterate through the sync progress of each folder of each account and get a
    normalized progress value (0: not started, 1: sync complete) for all syncs.
  */
  calculateProgress() {
    let count = 0;
    const total = _.values(this.state.syncState).reduce((outerSum, accountSyncState) => {
      return outerSum + _.values(accountSyncState.folderSyncProgress).reduce((innerSum, progress) => {
        count++;
        return innerSum + progress;
      }, 0)
    }, 0);

    return count ? (total / count) : 0;
  }

  hideExpandedState = (event) => {
    event.stopPropagation(); // So it doesn't reach the parent's onClick
    event.preventDefault();
    this.setState({expandedSync: false});
  }

  renderExpandedSyncState() {
    const accounts = _.map(this.state.syncState, (accountSyncState, accountId) => {
      const account = _.findWhere(AccountStore.accounts(), {id: accountId});
      if (!account) {
        return false;
      }

      const folderStates = _.map(accountSyncState.folderSyncProgress, (progress, name) => {
        return this.renderFolderProgress(name, progress)
      })

      return (
        <div className="account inner" key={accountId}>
          <h2>{account.emailAddress}</h2>
          {folderStates}
        </div>
      )
    });

    return (
      <div className="account-detail-area" key="expanded-sync-state">
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
    const progress = this.calculateProgress();
    if (progress === 1) {
      return false;
    }

    const innerContent = []
    if (AccountStore.accountsAreSyncing()) {
      if (progress === 0) {
        // On application start, the NylasSyncStatusStore takes awhile to populate
        // the folderSyncProgress fields. Don't let the user expand the details,
        // because they'll be empty.
        innerContent.push(<div className="inner" key="0">Preparing to sync your mailbox&hellip;</div>);
      } else {
        innerContent.push(<div className="inner" key="0">Syncing your mailbox&hellip;</div>);
        innerContent.push(this.renderExpandedSyncState());
      }
    }

    const classSet = classNames({
      'item': true,
      'expanded-sync': this.state.expandedSync,
    });

    return (
      <div
        className={classSet}
        key="initial-sync"
        onClick={() => (progress ? this.setState({expandedSync: !this.state.expandedSync}) : null)}
      >
        {this.renderProgressBar(progress)}
        {innerContent}
      </div>
    )
  }
}
