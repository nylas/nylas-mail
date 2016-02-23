import {React} from 'nylas-exports'
import OpenTrackingIcon from './open-tracking-icon'

export default class OpenTrackingMessageStatus extends OpenTrackingIcon {
  static displayName = "OpenTrackingMessageStatus";

  render() {
    const txt = this.state.opened ? "Read" : "Unread"
    return (
      <span>{this.renderImage()}&nbsp;{txt}</span>
    )
  }
}
