import { Actions, React, TaskFactory, PropTypes } from 'mailspring-exports';
import { RetinaImg } from 'mailspring-component-kit';

export default class ThreadToggleUnreadButton extends React.Component {
  static displayName = 'ThreadToggleUnreadButton';
  static containerRequired = false;
  static propTypes = {
    thread: PropTypes.object,
  };

  _onClick = e => {
    Actions.queueTask(
      TaskFactory.taskForInvertingUnread({
        source: 'Toolbar Button: Thread List',
        threads: [this.props.thread],
      })
    );
    Actions.popSheet();
    e.stopPropagation();
  };

  render() {
    const fragment = this.props.thread && this.props.thread.unread ? 'read' : 'unread';

    return (
      <button
        className="btn btn-toolbar"
        style={{ order: -105 }}
        title={`Mark as ${fragment}`}
        onClick={this._onClick}
      >
        <RetinaImg name={`toolbar-markas${fragment}.png`} mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }
}
