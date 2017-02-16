import React from 'react'
import {shell} from 'electron'
import RetinaImg from './retina-img'
import OpenIdentityPageButton from './open-identity-page-button'

export default function FeatureUsedUpModal(props = {}) {
  const gotoFeatures = () => shell.openExternal("https://nylas.com/nylas-pro");
  return (
    <div className={`feature-usage-modal ${props.modalClass}`}>
      <div className="feature-header">
        <div className="icon">
          <RetinaImg
            url={props.iconUrl}
            style={{position: "relative", top: "-2px"}}
            mode={RetinaImg.Mode.ContentPreserve}
          />
        </div>
        <h2 className="header-text">{props.headerText}</h2>
        <p className="recharge-text">{props.rechargeText}</p>
      </div>
      <div className="feature-cta">
        <h2>Want to <span className="feature-name">{props.featureName} more</span>?</h2>
        <div className="pro-description">
          <h3>Nylas Pro includes:</h3>
          <ul>
            <li>Unlimited Snoozing</li>
            <li>Unlimited Reminders</li>
            <li>Unlimited Mail Merge</li>
          </ul>
          <p>&hellip; plus <a onClick={gotoFeatures}>dozens of other features</a></p>
        </div>

        <OpenIdentityPageButton
          label="Upgrade"
          path="/dashboard?upgrade_to_pro=true"
          source={`${props.featureName}-Limit-Modal`}
          campaign="Limit-Modals"
          isCTA
        />
      </div>
    </div>
  )
}
FeatureUsedUpModal.propTypes = {
  modalClass: React.PropTypes.string.isRequired,
  featureName: React.PropTypes.string.isRequired,
  headerText: React.PropTypes.string.isRequired,
  rechargeText: React.PropTypes.string.isRequired,
  iconUrl: React.PropTypes.string.isRequired,
}
