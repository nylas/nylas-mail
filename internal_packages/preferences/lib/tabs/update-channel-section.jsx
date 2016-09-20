import React from 'react';
import {remote} from 'electron';
import {EdgehillAPI} from 'nylas-exports';

const autoUpdater = remote.getGlobal('application').autoUpdateManager;

class UpdateChannelSection extends React.Component {

  static displayName = 'UpdateChannelSection';

  constructor(props) {
    super(props);
    this.state = {
      current: {name: 'Loading...'},
      available: [{name: 'Loading...'}],
    }
  }

  componentDidMount() {
    this._refreshChannel();
    this._mounted = true;
  }

  componentWillUnmount() {
    this._mounted = false;
  }

  _refreshChannel() {
    EdgehillAPI.makeRequest({
      method: 'GET',
      path: `/update-channel`,
      qs: autoUpdater.parameters(),
      json: true,
    }).then(({current, available}) => {
      if (!this._mounted) { return; }
      this.setState({current, available});
    });
  }

  _onSelectedChannel = (event) => {
    const channel = event.target.value;

    this.setState({saving: true});

    EdgehillAPI.makeRequest({
      method: 'POST',
      path: `/update-channel`,
      qs: Object.assign({channel}, autoUpdater.parameters()),
      json: true,
    }).then(({current, available}) => {
      this.setState({current, available, saving: false});
    }).catch((err) => {
      this.setState({saving: false});
      NylasEnv.showErrorDialog(err.toString())
    });
  }

  render() {
    const {current, available, saving} = this.state;

    return (
      <section>
        <h6>Updates</h6>
        <label forHtml="">Release channel: </label>
        <select
          style={{minWidth: 130}}
          value={current.name}
          onChange={this._onSelectedChannel}
          disabled={saving}
        >
          {
            available.map((channel) => {
              return (<option value={channel.name} key={channel.name}>
                {channel.name[0].toUpperCase() + channel.name.substr(1)}
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
