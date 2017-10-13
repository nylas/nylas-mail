import { ListensToFluxStore, RetinaImg } from 'mailspring-component-kit';
import {
  Actions,
  React,
  Folder,
  PropTypes,
  TaskQueue,
  ExpungeAllInFolderTask,
  FocusedPerspectiveStore,
  ThreadCountsStore,
} from 'mailspring-exports';

class ThreadListEmptyFolderBar extends React.Component {
  static displayName = 'ThreadListEmptyFolderBar';

  static propTypes = {
    role: PropTypes.string,
    folders: PropTypes.array,
    count: PropTypes.number,
    busy: PropTypes.bool,
  };

  _onClick = () => {
    const { folders } = this.props;

    Actions.queueTasks(
      folders.map(
        folder =>
          new ExpungeAllInFolderTask({
            accountId: folder.accountId,
            folder,
          })
      )
    );
  };

  render() {
    const { role, count, busy } = this.props;
    if (!role || count === 0) {
      return false;
    }
    const term = role === 'trash' ? 'deleted' : role;

    return (
      <div className="thread-list-empty-folder-bar">
        <div className="notice">
          {`Showing ${(count / 1).toLocaleString()}
          ${count > 1 ? 'threads' : 'thread'}
          with ${term} messages`}
        </div>
        {busy ? (
          <div className="btn">
            <RetinaImg
              style={{ width: 16, height: 16 }}
              name="inline-loading-spinner.gif"
              mode={RetinaImg.Mode.ContentPreserve}
            />
          </div>
        ) : (
          <div className="btn" onClick={this._onClick}>{`Empty ${role} now`}</div>
        )}
      </div>
    );
  }
}

export default ListensToFluxStore(ThreadListEmptyFolderBar, {
  stores: [TaskQueue, ThreadCountsStore, FocusedPerspectiveStore],
  getStateFromStores: props => {
    const p = FocusedPerspectiveStore.current();
    const folders = (p && p.categories()) || [];

    if (
      !folders.length ||
      !folders.every(c => c instanceof Folder && (c.role === 'trash' || c.role === 'spam'))
    ) {
      return { role: null, folders: null };
    }

    return {
      folders,
      role: folders[0].role,
      busy:
        TaskQueue.findTasks(ExpungeAllInFolderTask).some(t =>
          folders.map(f => f.accountId).includes(t.accountId)
        ) > 0,
      count: folders.reduce(
        (sum, { id }) => sum + ThreadCountsStore.totalCountForCategoryId(id),
        0
      ),
    };
  },
});
