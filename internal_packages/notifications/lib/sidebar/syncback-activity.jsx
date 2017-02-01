import _ from 'underscore';
import {React, Utils} from 'nylas-exports';

export default class SyncbackActivity extends React.Component {
  static propTypes = {
    syncbackTasks: React.PropTypes.array,
  }

  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.isEqualReact(nextProps, this.props) ||
      !Utils.isEqualReact(nextState, this.state);
  }

  render() {
    const {syncbackTasks} = this.props;
    if (!syncbackTasks || syncbackTasks.length === 0) { return false; }

    const counts = {}
    this.props.syncbackTasks.forEach((task) => {
      const label = task.label ? task.label() : null;
      if (!label) { return; }
      if (!counts[label]) {
        counts[label] = 0;
      }
      counts[label] += +task.numberOfImpactedItems()
    });

    const ellipses = [1, 2, 3].map((i) => (
      <span key={`ellipsis${i}`} className={`ellipsis${i}`}>.</span>)
    );

    const items = _.pairs(counts).map(([label, count]) => {
      return (
        <div className="item" key={label}>
          <div className="inner">
            <span className="count">({count.toLocaleString()})</span>
            {label}{ellipses}
          </div>
        </div>
      )
    });

    if (items.length === 0) {
      items.push(
        <div className="item" key="no-labels">
          <div className="inner">
            Applying tasks
          </div>
        </div>
      )
    }

    return (
      <div>
        {items}
      </div>
    )
  }
}
