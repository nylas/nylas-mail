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
    };
  }

  render() {
    const {identity} = this.state;
    const {firstname, lastname, email} = identity;

    const logout = () => Actions.logoutNylasIdentity()
    const learnMore = () => shell.openExternal("https://nylas.com/nylas-pro")

    return (
      <div className="container-identity">
        <div className="id-header">
          Nylas ID:
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
                <OpenIdentityPageButton label="Upgrade to Nylas Pro" path="/dashboard?upgrade_to_pro=true" source="Preferences" campaign="Dashboard" />
                <div className="btn" onClick={logout}>Sign Out</div>
              </div>
            </div>
          </div>

          <div className="row payment-row">
            <div>
            You are using Nylas Mail Basic. Upgrade to Nylas Pro to unlock a more powerful email experience.
            </div>
            <div className="btn" onClick={learnMore}>Learn More about Nylas Pro</div>
          </div>
        </div>
      </div>
    );
  }
}

export default PreferencesIdentity;
