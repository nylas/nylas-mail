import React from 'react';

import {Flexbox,
  ScrollRegion} from 'nylas-component-kit';
import ActivityListStore from './activity-list-store';
import ActivityListItemContainer from './activity-list-item-container';


class ActivityList extends React.Component {

  static displayName = 'ActivityList';

  constructor() {
    super();
    this.state = this._getStateFromStores();
  }

  componentDidMount() {
    this._unsub = ActivityListStore.listen(this._onDataChanged);
  }

  componentWillUnmount() {
    NylasEnv.savedState.activityListViewed = Date.now() / 1000;
    this._unsub();
  }

  _onDataChanged = () => {
    this.setState(this._getStateFromStores());
  }

  _getStateFromStores() {
    return {
      actions: ActivityListStore.actions(),
      collapsedToggles: this.state ? this.state.collapsedToggles : {},
    }
  }

  _groupActions(actions) {
    const groupedActions = [];
    for (const action of actions) {
      if (groupedActions.length > 0) {
        const currentGroup = groupedActions[groupedActions.length - 1];
        if (action.messageId === currentGroup[0].messageId &&
          action.pluginId === currentGroup[0].pluginId) {
          groupedActions[groupedActions.length - 1].push(action);
        } else {
          groupedActions.push([action]);
        }
      } else {
        groupedActions.push([action]);
      }
    }
    return groupedActions;
  }

  renderActions() {
    const groupedActions = this._groupActions(this.state.actions);
    return groupedActions.map((group) => {
      return (
        <ActivityListItemContainer
          key={`${group[0].messageId}-${group[0].timestamp}`}
          group={group} />
      );
    });
  }

  render() {
    if (!this.state.actions) return null;
    return (
      <Flexbox
        direction="column"
        height="none"
        className="activity-list-container"
        tabIndex="-1">
        <ScrollRegion style={{height: "100%"}}>
          {this.renderActions()}
        </ScrollRegion>
      </Flexbox>
    );
  }
}

export default ActivityList;
