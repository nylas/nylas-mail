import React from 'react'
import {shell} from 'electron'
import Actions from '../flux/actions'
import RetinaImg from './retina-img'
import BillingModal from './billing-modal'
import IdentityStore from '../flux/stores/identity-store'

export default class FeatureUsedUpModal extends React.Component {
  static propTypes = {
    modalClass: React.PropTypes.string.isRequired,
    featureName: React.PropTypes.string.isRequired,
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
    shell.openExternal("https://getmerani.com/pro");
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
          <h2>Want to <span className="feature-name">{this.props.featureName} more</span>?</h2>
          <div className="pro-description">
            <h3>Merani Pro includes:</h3>
            <ul>
              <li>Unlimited Snoozing</li>
              <li>Unlimited Open &amp; Link Tracking</li>
              <li>Unlimited Reminders</li>
              <li>Unlimited Mail Merge</li>
            </ul>
            <p>&hellip; plus <a onClick={this.onGoToFeatures}>dozens of other features</a></p>
          </div>

          <button className="btn btn-cta btn-emphasis" onClick={this.onUpgrade}>
            Upgrade
          </button>
        </div>
      </div>
    )
  }
}
