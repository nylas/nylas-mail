import React from 'react'
import {shell} from 'electron'
import Actions from '../flux/actions'
import RetinaImg from './retina-img'
import BillingModal from './billing-modal'
import IdentityStore from '../flux/stores/identity-store'

export default class FeatureUsedUpModal extends React.Component {
  static propTypes = {
    modalClass: React.PropTypes.string.isRequired,
    headerText: React.PropTypes.string.isRequired,
    rechargeText: React.PropTypes.string.isRequired,
    iconUrl: React.PropTypes.string.isRequired,
  }

  componentDidMount() {
    this._mounted = true;

    IdentityStore.fetchSingleSignOnURL("/payment?embedded=true").then((upgradeUrl) => {
      if (!this._mounted) {
        return;
      }
      this.setState({upgradeUrl})
    })
  }

  componentWillUnmount() {
    this._mounted = false;
  }
  
  onGoToFeatures = () => {
    shell.openExternal("https://getmailspring.com/pro");
  };

  onUpgrade = (e) => {
    e.stopPropagation();
    Actions.openModal({
      component: (
        <BillingModal source="feature-limit" upgradeUrl={this.state.upgradeUrl} />
      ),
      width: BillingModal.IntrinsicWidth,
      height: BillingModal.IntrinsicHeight,
    });
  }

  render() {
    return (
      <div className={`feature-usage-modal ${this.props.modalClass}`}>
        <div className="feature-header">
          <div className="icon">
            <RetinaImg
              url={this.props.iconUrl}
              style={{position: "relative", top: "-2px"}}
              mode={RetinaImg.Mode.ContentPreserve}
            />
          </div>
          <h2 className="header-text">{this.props.headerText}</h2>
          <p className="recharge-text">{this.props.rechargeText}</p>
        </div>
        <div className="feature-cta">
          <div className="pro-description">
            <h3>Upgrade to Mailspring Pro</h3>
            <ul>
              <li>Unlimited Connected Accounts</li>
              <li>Unlimited Contact Profiles</li>
              <li>Unlimited Snoozing</li>
              <li>Unlimited Read Receipts</li>
              <li>Unlimited Link Tracking</li>
              <li>Unlimited Reminders</li>
              <li><a onClick={this.onGoToFeatures}>Dozens of other features!</a></li>
            </ul>
          </div>

          <button className="btn btn-large btn-cta btn-emphasis" onClick={this.onUpgrade}>
            Upgrade
          </button>
        </div>
      </div>
    )
  }
}
