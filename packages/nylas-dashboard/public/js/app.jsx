/* eslint react/react-in-jsx-scope: 0*/
const React = window.React;
const ReactDOM = window.ReactDOM;

class ErrorsRoot extends React.Component {
  render() {
    return <div />
  }
}

class Account extends React.Component {
  renderError() {
    const {account} = this.props;

    if (account.sync_error != null) {
      const error = {
        message: account.sync_error.message,
        stack: account.sync_error.stack ? account.sync_error.stack.split('\n').slice(0, 4) : [],
      }
      return (
        <div className="error">
          <strong> Sync Errored: </strong>
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
    return (
      <div className={`account${errorClass}`}>
        <h3>{account.email_address} {active ? '🌕' : '🌑'}</h3>
        <strong>{assignment}</strong>
        <pre>{JSON.stringify(account.sync_policy, null, 2)}</pre>
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

  render() {
    return (
      <div>
        {
          Object.keys(this.state.accounts).sort((a, b) => a.localeCompare(b)).map((id) =>
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
