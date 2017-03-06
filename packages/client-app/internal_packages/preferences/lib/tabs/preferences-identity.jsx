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
      height: 575,
      width: 412,
    })
  }

  _renderBasic() {
    const learnMore = () => shell.openExternal("https://nylas.com/nylas-pro")
    return (
      <div className="row padded">
        <div>
        You are using <strong>Nylas Mail Basic</strong>. Upgrade to Nylas Mail Pro to unlock a more powerful email experience.
        </div>
        <div className="subscription-actions">
          <div className="btn btn-emphasis" onClick={this._onUpgrade} style={{verticalAlign: "top"}}>Upgrade to Nylas Mail Pro</div>
          <div className="btn minor-width" onClick={learnMore}>Learn More</div>
        </div>
      </div>
    )
  }

  _renderPro() {
    return (
      <div className="row padded">
        <div>
        Thank you for using <strong>Nylas Mail Pro</strong>
        </div>
        <div className="subscription-actions">
          <OpenIdentityPageButton label="Manage Billing" path="/dashboard#billing" source="Preferences Billing" campaign="Dashboard" />
        </div>
      </div>
    )
  }

  render() {
    const {identity} = this.state;
    const {firstname, lastname, email} = identity;

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
              <div className="name">{firstname} {lastname}</div>
              <div className="email">{email}</div>
              <div className="identity-actions">
                <OpenIdentityPageButton label="Account Details" path="/dashboard" source="Preferences" campaign="Dashboard" />
                <div className="btn minor-width" onClick={logout}>Sign Out</div>
              </div>
            </div>
          </div>

          {this.state.identity.has_pro_access ? this._renderPro() : this._renderBasic()}

        </div>
      </div>
    );
  }
}

export default PreferencesIdentity;
