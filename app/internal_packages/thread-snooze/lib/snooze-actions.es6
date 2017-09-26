import Reflux from 'reflux';

const SnoozeActions = Reflux.createActions(['snoozeThreads']);

for (const key of Object.keys(SnoozeActions)) {
  SnoozeActions[key].sync = true;
}

export default SnoozeActions;
