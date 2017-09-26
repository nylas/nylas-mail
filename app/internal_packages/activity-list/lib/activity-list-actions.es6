import Reflux from 'reflux';

const ActivityListActions = Reflux.createActions(['resetSeen']);

for (const key of Object.keys(ActivityListActions)) {
  ActivityListActions[key].sync = true;
}

export default ActivityListActions;
