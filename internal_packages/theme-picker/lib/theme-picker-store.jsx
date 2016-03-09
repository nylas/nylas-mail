import NylasStore from 'nylas-store';
import {APMWrapper} from 'nylas-exports';

import ThemePickerActions from './theme-picker-actions';


class ThemePickerStore extends NylasStore {

  constructor() {
    super();
    this._apm = new APMWrapper();
  }

  activate = ()=> {
    this.unlisten = ThemePickerActions.uninstallTheme.listen(this.uninstallTheme);
  }

  uninstallTheme = (theme)=> {
    if (NylasEnv.packages.isPackageLoaded(theme.name)) {
      NylasEnv.packages.disablePackage(theme.name);
      NylasEnv.packages.unloadPackage(theme.name);
    }
    this._apm.uninstall(theme);
  }

  deactivate = ()=> {
    this.unlisten();
  }

}

export default new ThemePickerStore();
