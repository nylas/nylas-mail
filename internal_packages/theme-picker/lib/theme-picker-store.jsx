import React from 'react';
import Actions from '../../../src/flux/actions';
import NylasStore from 'nylas-store';

import ThemePicker from './theme-picker';


class ThemePickerStore extends NylasStore {

  constructor() {
    super();
  }

  activate = ()=> {
    this.disposable = NylasEnv.commands.add("body", "window:launch-theme-picker", () => {
      Actions.openModal({
        component: (<ThemePicker />),
        height: 390,
        width: 250,
      });
    });
  }

  deactivate = ()=> {
    this.disposable.dispose();
  }

}

export default new ThemePickerStore();
