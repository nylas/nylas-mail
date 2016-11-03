import {React} from 'nylas-exports';
import {Notification} from 'nylas-component-kit';

export default class DevModeNotification extends React.Component {
  static displayName = 'DevModeNotification';

  constructor() {
    super();
    // Don't need listeners to update this, since toggling dev mode reloads
    // the entire window anyway
    this.state = {
      inDevMode: NylasEnv.inDevMode(),
    }
  }

  render() {
    if (!this.state.inDevMode) {
      return <span />
    }
    return (
      <Notification
        priority="0"
        title="N1 is running in dev mode!"
      />
    )
  }
}
