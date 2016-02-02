import React, {Component, PropTypes} from 'react';
import {RetinaImg, Flexbox, EditableList} from 'nylas-component-kit';

class PreferencesAccountList extends Component {

  static propTypes = {
    accounts: PropTypes.array,
    selected: PropTypes.object,
    onAddAccount: PropTypes.func.isRequired,
    onReorderAccount: PropTypes.func.isRequired,
    onSelectAccount: PropTypes.func.isRequired,
    onRemoveAccount: PropTypes.func.isRequired,
  };

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
