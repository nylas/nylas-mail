/** @babel */
import React from 'react';
import Actions from '../../../src/flux/actions'

import ThemePicker from './theme-picker'


export function activate() {
  this.disposable = NylasEnv.commands.add("body",
                                          "window:launch-theme-picker",
                                          () => Actions.openModal(children=<ThemePicker />,
                                                                  height=400,
                                                                  width=250));
}

export function deactivate() {
  this.disposable.dispose();
}
