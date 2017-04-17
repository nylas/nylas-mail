/* eslint react/react-in-jsx-scope: 0*/
/* eslint no-console: 0*/
/* eslint global-require: 0*/

import {React} from 'nylas-exports';
import SetAllSyncPolicies from './set-all-sync-policies';
import SyncGraph from './sync-graph';
import SyncbackRequestDetails from './syncback-request-details';
import ElapsedTime from './elapsed-time';
import Modal from './modal';

import LocalDatabaseConnector from '../shared/local-database-connector';
import SyncProcessManager from '../local-sync-worker/sync-process-manager';

function calcAcctPosition(count) {
  const width = 280;
  const height = 490;
  const marginTop = 0;
  const marginSide = 0;

  const acctsPerRow = Math.floor((window.innerWidth - 2 * marginSide) / width);
  const row = Math.floor(count / acctsPerRow)
  const col = count - (row * acctsPerRow);
  const top = marginTop + (row * height);
  const left = marginSide + (width * col);

  return {left: left, top: top};
}

function formatSyncTimes(timestamp) {
  return timestamp / 1000;
}

class AccountCard extends React.Component {
  static propTypes = {
    account: React.PropTypes.object,
    count: React.PropTypes.number,
  };

  onClearError = () => {
    LocalDatabaseConnector.forShared().then(({Account}) => {
      Account.find({where: {id: this.props.account.id}}).then((account) => {
        account.syncError = null;
        account.save().then(() => {
          SyncProcessManager.wakeWorkerForAccount(account.id);
        });
      })
    });
  }

  onResetSync = () => {
    SyncProcessManager.removeWorkerForAccountId(this.props.account.id);
    LocalDatabaseConnector.destroyAccountDatabase(this.props.account.id);
    SyncProcessManager.addWorkerForAccount(this.props.account);
  }

  renderError() {
    const account = this.props.account;
    if (account.syncError === null) {
      return false;
    }
    const {message, stack} = account.syncError
    return (
      <div>
        <div className="section">Error</div>
        <Modal
          openLink={{text: message, className: 'error-link'}}
        >
          <pre>{JSON.stringify(stack, null, 2)}</pre>
        </Modal>
        <div className="action-link" onClick={this.onClearError}>Clear Error</div>
      </div>
    )
  }

  render() {
    const {account} = this.props;
    const errorClass = account.syncError ? ' errored' : ''

    const numStoredSyncs = account.lastSyncCompletions.length;
    const oldestSync = account.lastSyncCompletions[numStoredSyncs - 1];
    const newestSync = account.lastSyncCompletions[0];
    const avgBetweenSyncs = (newestSync - oldestSync) / (1000 * numStoredSyncs);

    let firstSyncDuration = "Incomplete";
    if (account.firstSyncCompletion) {
      firstSyncDuration = (new Date(account.firstSyncCompletion / 1) - new Date(account.createdAt)) / 1000;
    }

    const position = calcAcctPosition(this.props.count);

    return (
      <div
        className={`account${errorClass}`}
        style={{top: `${position.top}px`, left: `${position.left}px`}}
      >
        <h3>{account.emailAddress} [{account.id}]</h3>
        <button name="Reset sync" onClick={this.onResetSync}>Reset sync</button>
        <SyncbackRequestDetails accountId={account.id} />
        <div className="stats">
          <b>First Sync Duration (sec)</b>:
          <pre>{firstSyncDuration}</pre>
          <b> Average Time Between Syncs (sec)</b>:
          <pre>{avgBetweenSyncs}</pre>
          <b>Time Since Last Sync (sec)</b>:
          <pre>
            <ElapsedTime refTimestamp={newestSync} formatTime={formatSyncTimes} />
          </pre>
          <b>Recent Syncs</b>:
          <SyncGraph id={account.lastSyncCompletions.length} syncTimestamps={account.lastSyncCompletions} />
        </div>
        {this.renderError()}
      </div>
    );
  }
}


export default class Root extends React.Component {
  static displayName = 'Root';

  constructor() {
    super();
    this.state = {
      accounts: {},
      assignments: {},
      activeAccountIds: [],
    };
  }

  componentDidMount() {
    // just periodically poll. This is crazy nasty and violates separation of
    // concerns, but oh well. Replace it later.

    this._timer = setInterval(() => {
      LocalDatabaseConnector.forShared().then(({Account}) => {
        Account.findAll().then((accounts) => {
          this.setState({accounts});
        });
      });
    }, 1500);
  }

  componentWillUnmount() {
    clearTimeout(this._timer);
  }

  render() {
    const ids = Object.keys(this.state.accounts);
    let count = 0;
    const content = (
      <div id="accounts-wrapper">
        {
          ids.sort((a, b) => a / 1 - b / 1).map((id) =>
            <AccountCard
              key={id}
              active={this.state.activeAccountIds.includes(id)}
              assignment={this.state.assignments[id]}
              account={this.state.accounts[id]}
              count={count++}
            />
          )
        }
      </div>
    )

    return (
      <div>
        <SetAllSyncPolicies accountIds={ids.map((id) => parseInt(id, 10))} />
        {content}
      </div>
    )
  }
}

Root.propTypes = {
  collapsed: React.PropTypes.bool,
}
