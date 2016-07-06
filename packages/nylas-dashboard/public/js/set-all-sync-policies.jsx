const React = window.React;

class SetAllSyncPolicies extends React.Component {
  constructor(props) {
    super(props);
    this.state = {editMode: false};
  }

  edit() {
    this.setState({editMode: true})
  }

  applyToAllAccounts(accountIds) {
    const req = new XMLHttpRequest();
    const url = `${window.location.protocol}/sync-policy`;
    req.open("POST", url, true);
    req.setRequestHeader("Content-type", "application/json");
    req.onreadystatechange = () => {
      if (req.readyState === XMLHttpRequest.DONE) {
        console.log(req.responseText);
        if (req.status === 200) {
          this.setState({editMode: false});
        }
      }
    }

    const newPolicy = document.getElementById(`sync-policy-all`).value;
    req.send(JSON.stringify({
      sync_policy: newPolicy,
      account_ids: accountIds,
    }));
  }

  cancel() {
    this.setState({editMode: false});
  }

  render() {
    if (this.state.editMode) {
      return (
        <div className="modal-bg">
          <div className="sync-policy modal">
            <div className="section">Sync Policy</div>
            <textarea id="sync-policy-all">
            </textarea>
            <button onClick={() => this.applyToAllAccounts.call(this, this.props.accountIds)}>
              Apply To All Accounts
            </button>
            <span className="action-link" onClick={() => this.cancel.call(this)}> Cancel </span>
          </div>
        </div>
      )
    }
    return (
      <button id="set-all-sync" onClick={() => this.edit.call(this)}> Set All Sync Policies </button>
    )
  }
}

SetAllSyncPolicies.propTypes = {
  accountIds: React.PropTypes.arrayOf(React.PropTypes.number),
}

window.SetAllSyncPolicies = SetAllSyncPolicies;
