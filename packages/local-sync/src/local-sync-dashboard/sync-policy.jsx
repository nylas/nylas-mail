import {React} from 'nylas-exports';

export default class SyncPolicy extends React.Component {
  constructor(props) {
    super(props);
    this.state = {editMode: false};
    this.accountId = props.accountId;
  }

  edit() {
    this.setState({editMode: true})
  }

  save() {
    const req = new XMLHttpRequest();
    const url = `${window.location.protocol}/sync-policy/${this.accountId}`;
    req.open("POST", url, true);
    req.setRequestHeader("Content-type", "application/json");
    req.onreadystatechange = () => {
      if (req.readyState === XMLHttpRequest.DONE) {
        if (req.status === 200) {
          this.setState({editMode: false});
        }
      }
    }

    const newPolicy = document.getElementById(`sync-policy-${this.accountId}`).value;
    req.send(JSON.stringify({sync_policy: newPolicy}));
  }

  cancel() {
    this.setState({editMode: false});
  }

  render() {
    if (this.state.editMode) {
      const id = `sync-policy-${this.props.accountId}`;
      return (
        <div className="sync-policy">
          <div className="section">Sync Policy</div>
          <textarea id={id}>
            {this.props.stringifiedSyncPolicy}
          </textarea>
          <button onClick={() => this.save.call(this)}> Save </button>
          <div className="action-link cancel" onClick={() => this.cancel.call(this)}> Cancel </div>
        </div>

      )
    }
    return (
      <div className="sync-policy">
        <div className="section">Sync Policy</div>
        <pre>{this.props.stringifiedSyncPolicy}</pre>
        <div className="action-link" onClick={() => this.edit.call(this)}> Edit </div>
      </div>
    )
  }
}

SyncPolicy.propTypes = {
  accountId: React.PropTypes.number,
  stringifiedSyncPolicy: React.PropTypes.string,
}
