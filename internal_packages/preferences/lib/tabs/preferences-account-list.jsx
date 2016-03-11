import React, {Component, PropTypes} from 'react';
import {RetinaImg, Flexbox, EditableList} from 'nylas-component-kit';
import {Account} from 'nylas-exports';
import classnames from 'classnames';

class PreferencesAccountList extends Component {

  static propTypes = {
    accounts: PropTypes.array,
    selected: PropTypes.object,
    onAddAccount: PropTypes.func.isRequired,
    onReorderAccount: PropTypes.func.isRequired,
    onSelectAccount: PropTypes.func.isRequired,
    onRemoveAccount: PropTypes.func.isRequired,
  };

  _renderAccountStateIcon(account) {
    if (account.syncState !== "running") {
      return (<div className="sync-error-icon"><RetinaImg
        className="sync-error-icon"
        name="ic-settings-account-error.png"
        mode={RetinaImg.Mode.ContentIsMask} /></div>)
    }
  }

  _renderAccount = (account)=> {
    const label = account.label;
    const accountSub = `${account.name || 'No name provided'} <${account.emailAddress}>`;
    const syncError = account.syncState !== Account.SYNC_STATE_RUNNING;

    return (
      <div
        className={classnames({account: true, "sync-error": syncError})}
        key={account.id} >
        <Flexbox direction="row" style={{alignItems: 'middle'}}>
          <div style={{textAlign: 'center'}}>
            <RetinaImg
              name={syncError ? "ic-settings-account-error.png" : `ic-settings-account-${account.provider}.png`}
              fallback="ic-settings-account-imap.png"
              mode={RetinaImg.Mode.ContentPreserve} />
          </div>
          <div style={{flex: 1, marginLeft: 10}}>
            <div className="account-name">
              {label}
            </div>
            <div className="account-subtext">{accountSub} ({account.displayProvider()})</div>
          </div>
        </Flexbox>
      </div>
    );
  };

  render() {
    if (!this.props.accounts) {
      return <div className="account-list"></div>;
    }
    return (
      <div className="account-list">
        <EditableList
          items={this.props.accounts}
          itemContent={this._renderAccount}
          selected={this.props.selected}
          onReorderItem={this.props.onReorderAccount}
          onCreateItem={this.props.onAddAccount}
          onSelectItem={this.props.onSelectAccount}
          onDeleteItem={this.props.onRemoveAccount} />
      </div>
    );
  }

}

export default PreferencesAccountList;
