import React from 'react';
import classnames from 'classnames';

import {Flexbox,
  ScrollRegion} from 'nylas-component-kit';
import ActivityListStore from './activity-list-store';
import ActivityListActions from './activity-list-actions';
import ActivityListItemContainer from './activity-list-item-container';
import ActivityListEmptyState from './activity-list-empty-state';

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
    ActivityListActions.resetSeen();
    this._unsub();
  }

  _onDataChanged = () => {
    this.setState(this._getStateFromStores());
  }

  _getStateFromStores() {
    const actions = ActivityListStore.actions();
    return {
      actions: actions,
      empty: actions instanceof Array && actions.length === 0,
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
    if (this.state.empty) {
      return (
        <ActivityListEmptyState />
      )
    }

    const groupedActions = this._groupActions(this.state.actions);
    return groupedActions.map((group) => {
      return (
        <ActivityListItemContainer
          key={`${group[0].messageId}-${group[0].timestamp}`}
          group={group}
        />
      );
    });
  }

  render() {
    if (!this.state.actions) return null;

    const classes = classnames({
      "activity-list-container": true,
      "empty": this.state.empty,
    })
    return (
      <Flexbox
        direction="column"
        height="none"
        className={classes}
        tabIndex="-1"
      >
        <ScrollRegion style={{height: "100%"}}>
          {this.renderActions()}
        </ScrollRegion>
      </Flexbox>
    );
  }
}

export default ActivityList;
