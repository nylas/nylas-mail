import {React} from 'nylas-exports';
import {ipcRenderer, remote, shell} from 'electron';
import Notification from '../notification';

export default class UpdateNotification extends React.Component {
  static displayName = 'UpdateNotification';
  static containerRequired = false;

  constructor() {
    super();
    this.updater = remote.getGlobal('application').autoUpdateManager
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    this.disposable = NylasEnv.onUpdateAvailable(() => {
      this.setState(this.getStateFromStores())
    });
  }

  componentWillUnmount() {
    this.disposable.dispose();
  }

  getStateFromStores() {
    return {
      updateAvailable: this.updater.getState() === 'update-available',
      version: this.updater.releaseVersion,
    }
  }

  _onUpdate = () => {
    ipcRenderer.send('command', 'application:install-update')
  }

  _onViewChangelog = () => {
    shell.openExternal('https://github.com/nylas/N1/blob/master/CHANGELOG.md')
  }

  render() {
    if (!this.state.updateAvailable) {
      return <span />
    }
    const version = this.state.version ? `(${this.state.version})` : '';
    return (
      <Notification
        priority="4"
        title={`An update to N1 is available ${version}`}
        subtitle="View changelog"
        subtitleAction={this._onViewChangelog}
        icon="volstead-upgrade.png"
        actions={[{
          label: "Update",
          fn: this._onUpdate,
        }]}
      />
    )
  }
}
