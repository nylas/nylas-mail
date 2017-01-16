import React from 'react';
import {UpdateChannelStore} from 'nylas-exports';

class UpdateChannelSection extends React.Component {

  static displayName = 'UpdateChannelSection';

  constructor(props) {
    super(props);
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this._unsub = UpdateChannelStore.listen(() => {
      this.setState(Object.assign(this.getStateFromStores(), {saving: false}));
    });
    UpdateChannelStore.refreshChannel();
  }

  componentWillUnmount() {
    if (this._unsub) {
      this._unsub();
    }
  }

  getStateFromStores() {
    return {
      current: UpdateChannelStore.current(),
      available: UpdateChannelStore.available(),
    }
  }

  _onSelectedChannel = (event) => {
    this.setState({saving: true});
    UpdateChannelStore.setChannel(event.target.value);
  }

  render() {
    const {current, available, saving} = this.state;

    // HACK: Temporarily do not allow users to move on to the Salesforce channel.
    // In the future we could implement this server-side via a "public" flag.
    const allowedNames = ["stable", "nylas-mail", "beta"]

    if (NylasEnv.config.get("salesforce")) {
      allowedNames.push("salesforce");
    }

    const allowed = available.filter(c => {
      return allowedNames.includes(c.name) || c.name === current.name
    });

    const displayNameForChannel = (channel) => {
      if (channel.name === 'beta') {
        return 'Beta (Unstable)';
      } else if (channel.name === 'nylas-mail') {
        return 'Nylas Mail (Stable)';
      } else if (channel.name === 'stable') {
        return 'Nylas Pro (Stable)';
      }

      return channel.name[0].toUpperCase() + channel.name.substr(1)
    }

    return (
      <section>
        <h6>Updates</h6>
        <label htmlFor="release-channel">Release channel: </label>
        <select
          id="release-channel"
          style={{minWidth: 130}}
          value={current.name}
          onChange={this._onSelectedChannel}
          disabled={saving}
        >
          {
            allowed.map((channel) => {
              return (<option value={channel.name} key={channel.name}>
                {displayNameForChannel(channel)}
              </option>);
            })
          }
        </select>
        <p>
          Subscribe to different update channels to receive previews of new features.
          Note that some update channels may be less stable!
        </p>
      </section>
    );
  }

}

export default UpdateChannelSection;
