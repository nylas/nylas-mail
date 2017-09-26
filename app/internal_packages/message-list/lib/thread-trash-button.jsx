import {
  React,
  PropTypes,
  Actions,
  DOMUtils,
  TaskFactory,
  FocusedPerspectiveStore,
} from 'mailspring-exports';
import { RetinaImg } from 'nylas-component-kit';

export default class ThreadTrashButton extends React.Component {
  static displayName = 'ThreadTrashButton';
  static containerRequired = false;
  static propTypes = {
    thread: PropTypes.object.isRequired,
  };

  _onRemove = e => {
    if (!DOMUtils.nodeIsVisible(e.currentTarget)) {
      return;
    }
    const tasks = TaskFactory.tasksForMovingToTrash({
      source: 'Toolbar Button: Thread List',
      threads: [this.props.thread],
    });
    Actions.queueTasks(tasks);
    Actions.popSheet();
    e.stopPropagation();
  };

  render() {
    const allowed = FocusedPerspectiveStore.current().canMoveThreadsTo(
      [this.props.thread],
      'trash'
    );
    if (!allowed) {
      return <span />;
    }
    return (
      <button
        className="btn btn-toolbar"
        style={{ order: -106 }}
        title="Move to Trash"
        onClick={this._onRemove}
      >
        <RetinaImg name="toolbar-trash.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }
}
