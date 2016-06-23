/* eslint react/react-in-jsx-scope: 0*/

class Account extends React.Component {
  propTypes: {
    account: React.PropTypes.object,
    assignment: React.PropTypes.string,
  }

  render() {
    const {account, assignment} = this.props;
    return (
      <div className="account">
        <h3>{account.email_address}</h3>
        <strong>{assignment}</strong>
        <div>Sync Interval: {account.sync_policy.interval}ms</div>
        <div>Sync Idle Behavior: {account.sync_policy.afterSync}</div>
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
