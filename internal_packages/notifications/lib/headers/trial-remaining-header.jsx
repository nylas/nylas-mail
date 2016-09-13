import {shell} from 'electron';
import {React, IdentityStore} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';

let NUM_TRIAL_DAYS = 30;
const HANDLE_WIDTH = 100;

export default class TrialRemainingHeader extends React.Component {
  static displayName = "TrialRemainingHeader";

  constructor(props) {
    super(props)
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this._unlisten = IdentityStore.listen(() =>
      this.setState(this.getStateFromStores())
    );
  }

  componentWillUnmount() {
    if (this._unlisten) {
      this._unlisten();
    }
  }

  getStateFromStores = () => {
    const daysRemaining = IdentityStore.daysUntilSubscriptionRequired();
    if (daysRemaining > NUM_TRIAL_DAYS) {
      NUM_TRIAL_DAYS = daysRemaining;
      console.error("Unexpected number of days remaining in trial");
    }
    const inTrial = IdentityStore.subscriptionState() === IdentityStore.State.Trialing;
    const daysIntoTrial = NUM_TRIAL_DAYS - daysRemaining;
    const percentageIntoTrial = (NUM_TRIAL_DAYS - daysRemaining) / NUM_TRIAL_DAYS * 100;

    return {
      inTrial,
      daysRemaining,
      daysIntoTrial,
      percentageIntoTrial,
      handleStyle: {
        left: `calc(${percentageIntoTrial}% - ${HANDLE_WIDTH / 2}px)`,
      },
    };
  }

  _onUpgrade = () => {
    this.setState({buildingUpgradeURL: true});
    const utm = {
      source: "UpgradeBanner",
      campaign: "TrialStillActive",
    }
    IdentityStore.fetchSingleSignOnURL('/payment', utm).then((url) => {
      this.setState({buildingUpgradeURL: false});
      shell.openExternal(url);
    });
  }

  render() {
    if (this.state.inTrial && this.state.daysRemaining !== 0) {
      return (
        <div className="trial-remaining-header notifications-sticky">
          <div className="notifications-sticky-item">
            <RetinaImg
              className="icon"
              name="nylas-identity-seafoam.png"
              mode={RetinaImg.Mode.ContentPreserve}
              stype={{height: "20px"}}
            />
            Nylas N1 is in Trial Mode
            <div className="trial-timer-wrapper">
              <div className="trial-timer-progress" style={{width: `${this.state.percentageIntoTrial}%`}}></div>
              <div className="trial-timer-handle" style={this.state.handleStyle}>
                {NUM_TRIAL_DAYS - this.state.daysIntoTrial} Days Left
              </div>
            </div>
            {this.state.daysIntoTrial}/{NUM_TRIAL_DAYS} Trial Days
            <button className="upgrade-to-pro" onClick={this._onUpgrade}>
              {this.state.buildingUpgradeURL ? "Please Wait..." : "Upgrade to Nylas Pro"}
            </button>
          </div>
        </div>
      )
    }
    return <span />;
  }
}
