import Reflux from 'reflux';

const ActionNames = ['temporarilyEnableImages', 'permanentlyEnableImages'];

const Actions = Reflux.createActions(ActionNames);
ActionNames.forEach(name => {
  Actions[name].sync = true;
});

export default Actions;
