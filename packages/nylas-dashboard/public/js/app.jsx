/* eslint react/react-in-jsx-scope: 0*/
const React = window.React;
const ReactDOM = window.ReactDOM;
const {SyncPolicy, SetAllSyncPolicies, AccountFilter} = window;

class Account extends React.Component {
  renderError() {
    const {account} = this.props;

    if (account.sync_error != null) {
      const {message, stack} = account.sync_error
      const error = {
        message,
        stack: stack.slice(0, 4),
      }
      return (
        <div className="error">
          <pre>
            {JSON.stringify(error, null, 2)}
          </pre>
        </div>
      )
    }
    return <span />
  }

  render() {
    const {account, assignment, active} = this.props;
    const errorClass = account.sync_error ? ' errored' : ''
    const lastSyncCompletions = []
    for (const time of account.last_sync_completions) {
      lastSyncCompletions.push(
        <div key={time}>{new Date(time).toString()}</div>
      )
    }
    return (
      <div className={`account${errorClass}`}>
        <h3>{account.email_address} {active ? '🌕' : '🌑'}</h3>
        <strong>{assignment}</strong>
        <SyncPolicy
          accountId={account.id}
          stringifiedSyncPolicy={JSON.stringify(account.sync_policy, null, 2)}
        />
        <div className="section">Sync Cycles</div>
        <div>
          <b>First Sync Completion</b>:
          <pre>{new Date(account.first_sync_completed_at).toString()}</pre>
        </div>
        <div><b>Last Sync Completions:</b></div>
        <pre>{lastSyncCompletions}</pre>
        <div className="section">Error</div>
        {this.renderError()}
      </div>
    );
  }
}

Account.propTypes = {
  account: React.PropTypes.object,
  active: React.PropTypes.bool,
  assignment: React.PropTypes.string,
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
      url = `wss://${window.location.host}/accounts`;
    } else {
      url = `ws://${window.location.host}/accounts`;
    }
    this.websocket = new WebSocket(url);
    this.websocket.onopen = () => {
      this.websocket.send("Message to send");
    };
    this.websocket.onmessage = (evt) => {
      try {
        const msg = JSON.parse(evt.data);
        if (msg.cmd === 'ACCOUNT') {
          this.onReceivedAccount(msg.payload);
        }
        if (msg.cmd === 'ASSIGNMENTS') {
          this.onReceivedAssignments(msg.payload);
        }
        if (msg.cmd === 'ACTIVE') {
          this.onReceivedActiveAccountIds(msg.payload);
        }
      } catch (err) {
        console.error(err);
      }
    };
    this.websocket.onclose = () => {
      window.location.reload();
    };
  }

  onReceivedAssignments(assignments) {
    this.setState({assignments})
  }

  onReceivedActiveAccountIds(accountIds) {
    this.setState({activeAccountIds: accountIds})
  }

  onReceivedAccount(account) {
    const accounts = Object.assign({}, this.state.accounts);
    accounts[account.id] = account;
    this.setState({accounts});
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
