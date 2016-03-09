/** @babel */
import Reflux from 'reflux';

ThemePickerActions = Reflux.createActions([
  "uninstallTheme",
]);

for (key in ThemePickerActions) {
  ThemePickerActions[key].sync = true;
}

export default ThemePickerActions;
