import React from 'react';
import Actions from '../../../src/flux/actions';
import NylasStore from 'nylas-store';
import {APMWrapper} from 'nylas-exports';

import ThemePicker from './theme-picker';
import ThemePickerActions from './theme-picker-actions';


class ThemePickerStore extends NylasStore {

  constructor() {
    super();
  }

  activate = ()=> {
    this._apm = new APMWrapper();
    this.unlisten = ThemePickerActions.uninstallTheme.listen(this.uninstallTheme);
    this.disposable = NylasEnv.commands.add("body", "window:launch-theme-picker", () => {
      Actions.openModal({
        component: (<ThemePicker />),
        height: 400,
        width: 250,
      });
    });
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
    this.disposable.dispose();
  }

}

export default new ThemePickerStore();
