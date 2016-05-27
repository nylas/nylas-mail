import React from 'react';
import {Actions, IdentityStore} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';
import {shell} from 'electron';

class OpenIdentityPageButton extends React.Component {
  static propTypes = {
    path: React.PropTypes.string,
    label: React.PropTypes.string,
    img: React.PropTypes.string,
  }

  constructor(props) {
    super(props);
    this.state = {
      loading: false,
    };
  }

  _onClick = () => {
    IdentityStore.fetchSingleSignOnURL(this.props.path).then((url) => {
      this.setState({loading: false});
      shell.openExternal(url);
    });
  }

  render() {
    if (this.state.loading) {
      return (
        <div className="btn btn-disabled">
          <RetinaImg name="sending-spinner.gif" width={15} height={15} mode={RetinaImg.Mode.ContentPreserve} />
          &nbsp;{this.props.label}&hellip;
        </div>
      );
    }
    if (this.props.img) {
      return (
        <div className="btn" onClick={this._onClick}>
          <RetinaImg name={this.props.img} mode={RetinaImg.Mode.ContentPreserve} />
          &nbsp;&nbsp;{this.props.label}
        </div>
      )
    }
    return (
      <div className="btn" onClick={this._onClick}>{this.props.label}</div>
    );
  }
}

class PreferencesIdentity extends React.Component {
  static displayName = 'PreferencesIdentity';

  constructor() {
    super();
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this.unsubscribe = IdentityStore.listen(() => {
      this.setState(this.getStateFromStores());
    });
  }

  componentWillUnmount() {
    this.unsubscribe();
  }

  getStateFromStores() {
    return {
      identity: IdentityStore.identity(),
      subscriptionState: IdentityStore.subscriptionState(),
      trialDaysRemaining: IdentityStore.trialDaysRemaining(),
    };
  }

  _renderPaymentRow() {
    const {identity, trialDaysRemaining, subscriptionState} = this.state

    if (subscriptionState === IdentityStore.SubscriptionState.Trialing) {
      return (
        <div className="row payment-row">
          <div>
            There {(trialDaysRemaining > 1) ? `are ${trialDaysRemaining} days ` : `is one day `}
            remaining in your 30-day trial of Nylas Pro.
          </div>
          <OpenIdentityPageButton img="ic-upgrade.png" label="Upgrade to Nylas Pro" path="/dashboard#subscription" />
        </div>
      )
    }

    if (subscriptionState === IdentityStore.SubscriptionState.Lapsed) {
      return (
        <div className="row payment-row">
          <div>
            Your subscription has been cancelled or your billing information has expired.
            We've paused your mailboxes! Re-new your subscription to continue using N1.
          </div>
          <OpenIdentityPageButton img="ic-upgrade.png" label="Update Subscription" path="/dashboard#subscription" />
        </div>
      )
    }

    return (
      <div className="row payment-row">
        <div>
          Your subscription will renew on {new Date(identity.valid_until).toLocaleDateString()}. Enjoy N1!
        </div>
      </div>
    )
  }

  render() {
    const {identity} = this.state
    const {firstname, lastname, email} = identity
    return (
      <div className="container-identity">
        <div className="id-header">Nylas ID:</div>
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
                <OpenIdentityPageButton label="Account Details" path="/dashboard" />
                <div className="btn" onClick={() => Actions.logoutNylasIdentity()}>Sign Out</div>
              </div>
            </div>
          </div>
          {this._renderPaymentRow()}
        </div>
      </div>
    );
  }
}

export default PreferencesIdentity;
