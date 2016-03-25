import Reflux from 'reflux';

const ActionNames = [
  'setSignatureForAccountId',
];

const Actions = Reflux.createActions(ActionNames);
ActionNames.forEach((name) => {
  Actions[name].sync = true;
});

export default Actions;
