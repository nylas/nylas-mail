import {shell} from 'electron';
import {React, IdentityStore} from 'nylas-exports';


export default class TrialRemainingBlock extends React.Component {
  static displayName = "TrialRemainingBlock";

  constructor(props) {
    super(props)
    this.state = Object.assign({buildingUpgradeURL: false}, this.getStateFromStores());
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
    return {
      inTrial: (IdentityStore.subscriptionState() !== IdentityStore.State.Valid),
      daysRemaining: IdentityStore.daysUntilSubscriptionRequired(),
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

  _onMoreInfo = () => {
    shell.openExternal(`https://www.nylas.com/?utm_medium=N1&utm_source=UpgradeBanner&utm_campaign=TrialMoreInfo`);
  }

  render() {
    const {inTrial, daysRemaining, buildingUpgradeURL} = this.state;
    const daysTerm = daysRemaining === 1 ? 'day' : 'days';

    if (inTrial && (daysRemaining !== null)) {
      return (
        <div className="trial-remaining-block">
          {`${daysRemaining} ${daysTerm} left in `}free&nbsp;trial
          <a className="learn-more" onClick={this._onMoreInfo}>
            Learn more about <span>Nylas&nbsp;Pro</span>
          </a>
          <button className="btn subscribe" onClick={this._onUpgrade}>
            {buildingUpgradeURL ? "Please Wait..." : "Subscribe"}
          </button>
        </div>
      )
    }
    return <span />;
  }
}
