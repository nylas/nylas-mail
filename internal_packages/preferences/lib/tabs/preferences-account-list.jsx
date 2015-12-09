import React, {Component, PropTypes} from 'react';
import {RetinaImg, Flexbox, EditableList} from 'nylas-component-kit';

class PreferencesAccountList extends Component {

  static propTypes = {
    accounts: PropTypes.array,
    onAddAccount: PropTypes.func.isRequired,
    onAccountSelected: PropTypes.func.isRequired,
    onRemoveAccount: PropTypes.func.isRequired,
  }

  _onAccountSelected = (accountComp, idx)=> {
    this.props.onAccountSelected(this.props.accounts[idx], idx);
  }

  _onRemoveAccount = (accountComp, idx)=> {
    this.props.onRemoveAccount(this.props.accounts[idx], idx);
  }

  _renderAccount = (account)=> {
    const label = account.label;
    const accountSub = `${account.name || 'No name provided'} <${account.emailAddress}>`;

    return (
      <div
        className="account"
        key={account.id} >
        <Flexbox direction="row" style={{alignItems: 'middle'}}>
          <div style={{textAlign: 'center'}}>
            <RetinaImg
              name={`ic-settings-account-${account.provider}.png`}
              fallback="ic-settings-account-imap.png"
              mode={RetinaImg.Mode.ContentPreserve} />
          </div>
          <div style={{flex: 1, marginLeft: 10}}>
            <div className="account-name">{label}</div>
            <div className="account-subtext">{accountSub} ({account.displayProvider()})</div>
          </div>
        </Flexbox>
      </div>
    );
  }

  render() {
    if (!this.props.accounts) {
      return <div className="account-list"></div>;
    }
    return (
      <div className="account-list">
        <EditableList
          allowEmptySelection={false}
          onCreateItem={this.props.onAddAccount}
          onItemSelected={this._onAccountSelected}
          onDeleteItem={this._onRemoveAccount}>
          {this.props.accounts.map(this._renderAccount)}
        </EditableList>
      </div>
    );
  }

}

export default PreferencesAccountList;
