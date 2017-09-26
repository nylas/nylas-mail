import Reflux from 'reflux';

const OnboardingActions = Reflux.createActions([
  'moveToPreviousPage',
  'moveToPage',
  'setAccount',
  'chooseAccountProvider',
  'identityJSONReceived',
  'finishAndAddAccount',
]);

for (const key of Object.keys(OnboardingActions)) {
  OnboardingActions[key].sync = true;
}

export default OnboardingActions;
