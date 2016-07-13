/* eslint react/react-in-jsx-scope: 0*/
/* eslint no-console: 0*/

const React = window.React;
const ReactDOM = window.ReactDOM;
const {
  SyncPolicy,
  SetAllSyncPolicies,
  AccountFilter,
  SyncGraph,
  SyncbackRequestDetails,
} = window;

function calcAcctPosition(count) {
  const width = 340;
  const height = 540;
  const marginTop = 100;
  const marginSide = 0;

  const acctsPerRow = Math.floor((window.innerWidth - 2 * marginSide) / width);
  const row = Math.floor(count / acctsPerRow)
  const col = count - (row * acctsPerRow);
  const top = marginTop + (row * height);
  const left = marginSide + (width * col);

  return {left: left, top: top};
}

class Account extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      accountId: props.account.id,
    }
  }
  clearError() {
    const req = new XMLHttpRequest();
    const url = `${window.location.protocol}/accounts/${this.state.accountId}/clear-sync-error`;
    req.open("PUT", url, true);
    req.onreadystatechange = () => {
      if (req.readyState === XMLHttpRequest.DONE) {
        if (req.status === 200) {
          // Would setState here, but external updates currently refresh the account
        } else {
          console.error(req.responseText);
        }
      }
    }
    req.send();
  }
  renderError() {
    const {account} = this.props;

    if (account.sync_error != null) {
      const {message, stack} = account.sync_error
      const error = {
        message,
        stack: stack.slice(0, 4),
      }
      return (
        <div>
          <div className="section">Error</div>
          <div className="action-link" onClick={() => this.clearError()}>Clear Error</div>
          <div className="error">
            <pre>
              {JSON.stringify(error, null, 2)}
            </pre>
          </div>
        </div>
      )
    }
    return <span />
  }

  render() {
    const {account, assignment, active} = this.props;
    const errorClass = account.sync_error ? ' errored' : ''

    const numStoredSyncs = account.last_sync_completions.length;
    const oldestSync = account.last_sync_completions[numStoredSyncs - 1];
    const newestSync = account.last_sync_completions[0];
    const avgBetweenSyncs = (newestSync - oldestSync) / (1000 * numStoredSyncs);
    const timeSinceLastSync = (Date.now() - newestSync) / 1000;

    let firstSyncDuration = "Incomplete";
    if (account.first_sync_completion) {
      firstSyncDuration = (new Date(account.first_sync_completion) - new Date(account.created_at)) / 1000;
    }

    const position = calcAcctPosition(this.props.count);

    return (
      <div
        className={`account${errorClass}`}
        style={{top: `${position.top}px`, left: `${position.left}px`}}
      >
        <h3>{account.email_address} [{account.id}] {active ? '🌕' : '🌑'}</h3>
        <strong>{assignment}</strong>
        <SyncbackRequestDetails accountId={account.id} />
        <SyncPolicy
          accountId={account.id}
          stringifiedSyncPolicy={JSON.stringify(account.sync_policy, null, 2)}
        />
        <div className="section">Sync Cycles</div>
        <div className="stats">
          <b>First Sync Duration (seconds)</b>:
          <pre>{firstSyncDuration}</pre>
          <b> Average Time Between Syncs (seconds)</b>:
          <pre>{avgBetweenSyncs}</pre>
          <b>Time Since Last Sync (seconds)</b>:
          <pre>{timeSinceLastSync}</pre>
          <b>Recent Syncs</b>:
          <SyncGraph id={account.last_sync_completions.length} syncTimestamps={account.last_sync_completions} />
        </div>
        {this.renderError()}
      </div>
    );
  }
}

Account.propTypes = {
  account: React.PropTypes.object,
  active: React.PropTypes.bool,
  assignment: React.PropTypes.string,
  count: React.PropTypes.number,
}

class Root extends React.Component {

  constructor() {
    super();
    this.state = {
      accounts: {},
      assignments: {},
      activeAccountIds: [],
      visibleAccounts: AccountFilter.states.all,
    };
  }

  componentDidMount() {
    let url = null;
    if (window.location.protocol === "https:") {
      url = `wss://${window.location.host}/websocket`;
    } else {
      url = `ws://${window.location.host}/websocket`;
    }
    this.websocket = new WebSocket(url);
    this.websocket.onopen = () => {
      this.websocket.send("Message to send");
    };
    this.websocket.onmessage = (evt) => {
      try {
        const msg = JSON.parse(evt.data);
        if (msg.cmd === 'UPDATE') {
          this.onReceivedUpdate(msg.payload);
        }
      } catch (err) {
        console.error(err);
      }
    };
    this.websocket.onclose = () => {
      window.location.reload();
    };
  }

  onReceivedUpdate(update) {
    const accounts = Object.assign({}, this.state.accounts);
    for (const account of update.updatedAccounts) {
      accounts[account.id] = account;
    }

    this.setState({
      assignments: update.assignments || this.state.assignments,
      activeAccountIds: update.activeAccountIds || this.state.activeAccountIds,
      accounts: accounts,
    })
  }

  onFilter() {
    this.setState({visibleAccounts: document.getElementById('account-filter').value});
  }

  render() {
    let ids = Object.keys(this.state.accounts);

    switch (this.state.visibleAccounts) {
      case AccountFilter.states.errored:
        ids = ids.filter((id) => this.state.accounts[id].sync_error)
        break;
      case AccountFilter.states.notErrored:
        ids = ids.filter((id) => !this.state.accounts[id].sync_error)
        break;
      default:
        break;
    }

    let count = 0;

    return (
      <div>
        <AccountFilter id="account-filter" onChange={() => this.onFilter.call(this)} />
        <SetAllSyncPolicies accountIds={ids.map((id) => parseInt(id, 10))} />
        {
          ids.sort((a, b) => a.localeCompare(b)).map((id) =>
            <Account
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
  }
}

ReactDOM.render(
  <Root />,
  document.getElementById('root')
);
