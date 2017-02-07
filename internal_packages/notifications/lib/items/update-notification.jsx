import {React} from 'nylas-exports';
import {ipcRenderer, remote, shell} from 'electron';
import {Notification} from 'nylas-component-kit';

export default class UpdateNotification extends React.Component {
  static displayName = 'UpdateNotification';

  constructor() {
    super();
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
    const updater = remote.getGlobal('application').autoUpdateManager;

    return {
      updateAvailable: updater.getState() === 'update-available',
      version: updater.releaseVersion,
    }
  }

  _onUpdate = () => {
    ipcRenderer.send('command', 'application:install-update')
  }

  _onViewChangelog = () => {
    shell.openExternal('https://github.com/nylas/nylas-mail/releases/latest')
  }

  render() {
    if (!this.state.updateAvailable) {
      return <span />
    }
    const version = this.state.version ? `(${this.state.version})` : '';
    return (
      <Notification
        priority="4"
        title={`An update to Nylas Mail is available ${version}`}
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
