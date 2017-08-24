import React from 'react';
import {Actions, IdentityStore} from 'nylas-exports';
import {OpenIdentityPageButton, BillingModal, RetinaImg} from 'nylas-component-kit';
import {shell} from 'electron';

class PreferencesIdentity extends React.Component {
  static displayName = 'PreferencesIdentity';

  constructor() {
    super();
    this.state = this._getStateFromStores();
  }

  componentDidMount() {
    this.unsubscribe = IdentityStore.listen(() => {
      this.setState(this._getStateFromStores());
    });
  }

  componentWillUnmount() {
    this.unsubscribe();
  }

  _getStateFromStores() {
    return {
      identity: IdentityStore.identity() || {},
    };
  }

  _onUpgrade = () => {
    Actions.openModal({
      component: (
        <BillingModal source="preferences" />
      ),
      width: BillingModal.IntrinsicWidth,
      height: BillingModal.IntrinsicHeight,
    })
  }

  _renderBasic() {
    const learnMore = () => shell.openExternal("https://getmerani.com/pro")
    return (
      <div className="row padded">
        <div>
        You are using <strong>Merani Basic</strong>. Upgrade to Merani Pro to unlock a more powerful email experience.
        </div>
        <div className="subscription-actions">
          <div className="btn btn-emphasis" onClick={this._onUpgrade} style={{verticalAlign: "top"}}>Upgrade to Merani Pro</div>
          <div className="btn minor-width" onClick={learnMore}>Learn More</div>
        </div>
      </div>
    )
  }

  _renderPaidPlan(planName) {
    return (
      <div className="row padded">
        <div>
        Thank you for using <strong style={{textTransform: 'capitalize'}}>{`Merani ${planName}`}</strong>
        </div>
        <div className="subscription-actions">
          <OpenIdentityPageButton label="Manage Billing" path="/dashboard#billing" source="Preferences Billing" campaign="Dashboard" />
        </div>
      </div>
    )
  }

  render() {
    const {identity} = this.state;
    const {firstName, lastName, emailAddress, stripePlan} = identity;

    const logout = () => Actions.logoutNylasIdentity()

    return (
      <div className="container-identity">
        <div className="identity-content-box">

          <div className="row info-row">
            <div className="logo">
              <RetinaImg
                name="prefs-identity-nylas-logo.png"
                mode={RetinaImg.Mode.ContentPreserve}
              />
            </div>
            <div className="identity-info">
              <div className="name">{firstName} {lastName}</div>
              <div className="email">{emailAddress}</div>
              <div className="identity-actions">
                <OpenIdentityPageButton label="Account Details" path="/dashboard" source="Preferences" campaign="Dashboard" />
                <div className="btn minor-width" onClick={logout}>Sign Out</div>
              </div>
            </div>
          </div>
          {stripePlan === 'Basic' ? this._renderBasic() : this._renderPaidPlan(stripePlan)}
        </div>
      </div>
    );
  }
}

export default PreferencesIdentity;
