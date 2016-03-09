/** @babel */
import React from 'react';
import Actions from '../../../src/flux/actions';

import ThemePicker from './theme-picker';
import ThemePickerStore from './theme-picker-store';


export function activate() {
  ThemePickerStore.activate();
  this.disposable = NylasEnv.commands.add("body", "window:launch-theme-picker",  () => {
    Actions.openModal(
       children=<ThemePicker />,
       height=400,
       width=250,
    );
  });
}

export function deactivate() {
  ThemePickerStore.deactivate();
  this.disposable.dispose();
}
