import { Actions, React, ReactDOM, PropTypes } from 'mailspring-exports';
import { RetinaImg } from 'mailspring-component-kit';
import ThreadSharingPopover from './thread-sharing-popover';

export default class ThreadSharingButton extends React.Component {
  static displayName = 'ThreadSharingButton';

  static containerRequired = false;

  static propTypes = {
    items: PropTypes.array,
    thread: PropTypes.object,
  };

  componentWillReceiveProps(nextProps) {
    if (nextProps.thread.id !== this.props.thread.id) {
      Actions.closePopover();
    }
  }

  _onClick = () => {
    const { thread } = this.props;

    Actions.openPopover(
      <ThreadSharingPopover
        thread={thread}
        accountId={thread.accountId}
        closePopover={Actions.closePopover}
      />,
      {
        originRect: ReactDOM.findDOMNode(this).getBoundingClientRect(),
        direction: 'down',
      }
    );
  };

  render() {
    if (this.props.items && this.props.items.length > 1) {
      return <span />;
    }

    return (
      <button
        className="btn btn-toolbar thread-sharing-button"
        title="Share"
        style={{ marginRight: 0 }}
        onClick={this._onClick}
      >
        <RetinaImg name="ic-toolbar-native-share.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }
}
