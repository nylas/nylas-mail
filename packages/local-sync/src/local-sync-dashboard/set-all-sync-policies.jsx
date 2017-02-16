import {React} from 'nylas-exports';
import Modal from './modal';

export default class SetAllSyncPolicies extends React.Component {

  applyToAllAccounts(accountIds) {
    const req = new XMLHttpRequest();
    const url = `${window.location.protocol}/sync-policy`;
    req.open("POST", url, true);
    req.setRequestHeader("Content-type", "application/json");
    req.onreadystatechange = () => {
      if (req.readyState === XMLHttpRequest.DONE) {
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

  render() {
    return (
      <Modal
        className="sync-policy"
        openLink={{
          text: "Set sync policies for currently displayed accounts",
          className: "action-link",
          id: "open-all-sync",
        }}
        actionElems={[
          {
            title: "Apply To All Displayed Accounts",
            action: () => this.applyToAllAccounts.call(this, this.props.accountIds),
            type: 'button',
            className: 'right-action',
          }, {
            title: "Cancel",
            type: 'div',
            className: 'action-link cancel',
          },
        ]}
      >
        <h3>Sync Policy</h3>
        <textarea id="sync-policy-all" />
      </Modal>
    )
  }
}

SetAllSyncPolicies.propTypes = {
  accountIds: React.PropTypes.arrayOf(React.PropTypes.number),
}
