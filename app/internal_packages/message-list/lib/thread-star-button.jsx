import { React, PropTypes, Actions, TaskFactory } from 'mailspring-exports';
import { RetinaImg } from 'nylas-component-kit';

export default class StarButton extends React.Component {
  static displayName = 'StarButton';
  static containerRequired = false;
  static propTypes = {
    thread: PropTypes.object,
  };

  _onStarToggle = e => {
    Actions.queueTask(
      TaskFactory.taskForInvertingStarred({
        source: 'Toolbar Button: Message List',
        threads: [this.props.thread],
      })
    );
    e.stopPropagation();
  };

  render() {
    const selected = this.props.thread && this.props.thread.starred;
    return (
      <button
        className="btn btn-toolbar"
        style={{ order: -104 }}
        title={selected ? 'Remove star' : 'Add star'}
        onClick={this._onStarToggle}
      >
        <RetinaImg
          name="toolbar-star.png"
          mode={RetinaImg.Mode.ContentIsMask}
          selected={selected}
        />
      </button>
    );
  }
}
