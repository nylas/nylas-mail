import classNames from 'classnames';
import {Actions, React, Utils} from 'nylas-exports';

import InitialSyncActivity from './initial-sync-activity';
import SyncbackActivity from './syncback-activity';

export default class SyncActivity extends React.Component {

  static propTypes = {
    initialSync: React.PropTypes.bool,
    syncbackTasks: React.PropTypes.array,
  }

  constructor() {
    super()
    this.state = {
      expanded: false,
      blink: false,
    }
    this.mounted = false;
  }

  componentDidMount() {
    this.mounted = true;
    this.unsub = Actions.expandInitialSyncState.listen(this.showExpandedState);
  }

  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.isEqualReact(nextProps, this.props) ||
    !Utils.isEqualReact(nextState, this.state);
  }

  componentWillUnmount() {
    this.mounted = false;
    this.unsub();
  }

  showExpandedState = () => {
    if (!this.state.expanded) {
      this.setState({expanded: true});
    } else {
      this.setState({blink: true});
      setTimeout(() => {
        if (this.mounted) {
          this.setState({blink: false});
        }
      }, 1000)
    }
  }

  hideExpandedState = () => {
    this.setState({expanded: false});
  }

  _renderInitialSync() {
    if (!this.props.initialSync) { return false; }
    return <InitialSyncActivity />
  }

  _renderSyncbackTasks() {
    return <SyncbackActivity syncbackTasks={this.props.syncbackTasks} />
  }

  _renderExpandedDetails() {
    return (
      <div>
        <a className="close-expanded" onClick={this.hideExpandedState}>Hide</a>
        {this._renderSyncbackTasks()}
        {this._renderInitialSync()}
      </div>
    )
  }

  render() {
    const {initialSync, syncbackTasks} = this.props;
    if (!initialSync && (!syncbackTasks || syncbackTasks.length === 0)) {
      return false;
    }

    const classSet = classNames({
      'item': true,
      'expanded-sync': this.state.expanded,
      'blink': this.state.blink,
    });

    const ellipses = [1, 2, 3].map((i) => <span className={`ellipsis${i}`}>.</span>);

    return (
      <div
        className={classSet}
        key="sync-activity"
        onClick={() => (this.setState({expanded: !this.state.expanded}))}
      >
        <div className="inner clickable">Syncing your mailbox{ellipses}</div>
        {this.state.expanded ? this._renderExpandedDetails() : false}
      </div>
    )
  }
}
