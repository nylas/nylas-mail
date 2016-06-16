import React from 'react';
import {Actions, IdentityStore} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';
import {shell} from 'electron';

class OpenIdentityPageButton extends React.Component {
  static propTypes = {
    path: React.PropTypes.string,
    label: React.PropTypes.string,
    source: React.PropTypes.string,
    campaign: React.PropTypes.string,
    img: React.PropTypes.string,
  }

  constructor(props) {
    super(props);
    this.state = {
      loading: false,
    };
  }

  _onClick = () => {
    this.setState({loading: true});
    IdentityStore.fetchSingleSignOnURL(this.props.path, {
      source: this.props.source,
      campaign: this.props.campaign,
      content: this.props.label,
    }).then((url) => {
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
    this.state.refreshing = false;
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
      identity: IdentityStore.identity() || {},
      subscriptionState: IdentityStore.subscriptionState(),
      daysUntilSubscriptionRequired: IdentityStore.daysUntilSubscriptionRequired(),
    };
  }

  _onRefresh = () => {
    this.setState({refreshing: true});
    IdentityStore.refreshStatus().finally(() => {
      this.setState({refreshing: false});
    });
  }

  _renderPaymentRow() {
    const {identity, daysUntilSubscriptionRequired, subscriptionState} = this.state

    if (subscriptionState === IdentityStore.State.Trialing) {
      let msg = "You have not upgraded to Nylas Pro.";
      if (daysUntilSubscriptionRequired > 1) {
        msg = `There are ${daysUntilSubscriptionRequired} days remaining in your 30-day trial of Nylas Pro.`;
      } else if (daysUntilSubscriptionRequired === 1) {
        msg = `There is one day remaining in your trial of Nylas Pro. Upgrade today!`;
      }
      return (
        <div className="row payment-row">
          <div>{msg}</div>
          <OpenIdentityPageButton img="ic-upgrade.png" label="Upgrade to Nylas Pro" path="/payment" campaign="Upgrade" source="Preferences" />
        </div>
      )
    }

    if (subscriptionState === IdentityStore.State.Lapsed) {
      return (
        <div className="row payment-row">
          <div>
            Your subscription has been canceled or your billing information has expired.
            We've paused your mailboxes! Renew your subscription to continue using N1.
          </div>
          <OpenIdentityPageButton img="ic-upgrade.png" label="Update Subscription" path="/dashboard#subscription" campaign="Renew" source="Preferences" />
        </div>
      )
    }

    return (
      <div className="row payment-row">
        <div>
          Your subscription is valid until {new Date(identity.valid_until * 1000).toLocaleDateString()}. Enjoy N1!
        </div>
      </div>
    )
  }

  render() {
    const {identity, refreshing} = this.state;
    const {firstname, lastname, email} = identity;

    let refresh = null;
    if (refreshing) {
      refresh = (
        <a className="refresh spinning" onClick={this._onRefresh}>
          Refreshing... <RetinaImg style={{verticalAlign: 'sub'}} name="ic-refresh.png" mode={RetinaImg.Mode.ContentIsMask} />
        </a>
      )
    } else {
      refresh = (
        <a className="refresh" onClick={this._onRefresh}>
          Refresh <RetinaImg style={{verticalAlign: 'sub'}} name="ic-refresh.png" mode={RetinaImg.Mode.ContentIsMask} />
        </a>
      )
    }

    return (
      <div className="container-identity">
        <div className="id-header">
          Nylas ID:
          {refresh}
        </div>
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
