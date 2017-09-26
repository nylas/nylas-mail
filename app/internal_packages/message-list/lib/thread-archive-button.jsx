import { RetinaImg } from 'nylas-component-kit';
import {
  Actions,
  React,
  PropTypes,
  TaskFactory,
  DOMUtils,
  FocusedPerspectiveStore,
} from 'nylas-exports';

export default class ThreadArchiveButton extends React.Component {
  static displayName = 'ThreadArchiveButton';
  static containerRequired = false;
  static propTypes = {
    thread: PropTypes.object.isRequired,
  };

  _onArchive = e => {
    if (!DOMUtils.nodeIsVisible(e.currentTarget)) {
      return;
    }
    const tasks = TaskFactory.tasksForArchiving({
      threads: [this.props.thread],
      source: 'Toolbar Button: Message List',
    });
    Actions.queueTasks(tasks);
    Actions.popSheet();
    e.stopPropagation();
  };

  render() {
    const canArchiveThreads = FocusedPerspectiveStore.current().canArchiveThreads([
      this.props.thread,
    ]);
    if (!canArchiveThreads) {
      return <span />;
    }

    return (
      <button
        className="btn btn-toolbar btn-archive"
        style={{ order: -107 }}
        title="Archive"
        onClick={this._onArchive}
      >
        <RetinaImg name="toolbar-archive.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }
}
