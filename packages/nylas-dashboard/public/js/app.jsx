/* eslint react/react-in-jsx-scope: 0*/

class ErrorsRoot extends React.Component {
  render() {
    return <div />
  }
}

class Account extends React.Component {
  propTypes: {
    account: React.PropTypes.object,
    assignment: React.PropTypes.string,
  }

  renderError() {
    const {account} = this.props
    if (account.sync_error != null) {
      const error = {
        message: account.sync_error.message,
        stack: account.sync_error.stack.split('\n').slice(0, 4),
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
    const {account, assignment} = this.props;
    const errorClass = account.sync_error ? ' errored' : ''
    return (
      <div className={`account${errorClass}`}>
        <h3>{account.email_address}</h3>
        <strong>{assignment}</strong>
        <pre>{JSON.stringify(account.sync_policy, null, 2)}</pre>
        {this.renderError()}
      </div>
    );
  }
}

class Root extends React.Component {

  constructor() {
    super();
    this.state = {
      accounts: {},
      assignments: {},
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

  onReceivedAccount(account) {
    const accounts = Object.assign({}, this.state.accounts);
    accounts[account.id] = account;
    this.setState({accounts});
  }

  render() {
    return (
      <div>
        {
          Object.keys(this.state.accounts).sort((a, b) => a.compare(b)).map((key) =>
            <Account
              key={key}
              assignment={this.state.assignments[key]}
              account={this.state.accounts[key]}
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
