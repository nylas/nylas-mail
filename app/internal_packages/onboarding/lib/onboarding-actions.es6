import Reflux from 'reflux';

const OnboardingActions = Reflux.createActions([
  "setAccountInfo",
  "setAccountType",
  "moveToPreviousPage",
  "moveToPage",
  "identityJSONReceived",
  "accountJSONReceived",
]);

for (const key of Object.keys(OnboardingActions)) {
  OnboardingActions[key].sync = true;
}

export default OnboardingActions;
