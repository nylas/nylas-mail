import {React, UpdateChannelStore} from 'nylas-exports';
import {Notification} from 'nylas-component-kit';

export default class UnstableChannelNotification extends React.Component {
  static displayName = 'UnstableChannelNotification';

  constructor() {
    super();
    this.state = {
      isDismissed: false,
      isUnstableChannel: UpdateChannelStore.currentIsUnstable(),
    }
  }

  componentDidMount() {
    this._unsub = UpdateChannelStore.listen(() => {
      this.setState({
        isUnstableChannel: UpdateChannelStore.currentIsUnstable(),
      });
    });
  }

  componentWillUnmount() {
    if (this._unsub) {
      this._unsub();
    }
  }

  _onDismiss = () => {
    this.setState({isDismissed: true});
  }

  _onReportIssue = () => {
    NylasEnv.windowEventHandler.openLink({href: 'mailto:support@nylas.com'})
  }

  render() {
    if (!this.state.isUnstableChannel || this.state.isDismissed) {
      return <span />
    }
    return (
      <Notification
        priority="0"
        title="You're on a pre-release channel. We'd love your feedback."
        subtitle="You can switch back to stable from N1's preferences."
        icon="volstead-defaultclient.png"
        actions={[{
          label: "Feedback",
          fn: this._onReportIssue,
        }, {
          label: "Dismiss",
          fn: this._onDismiss,
        }]}
      />
    )
  }
}
