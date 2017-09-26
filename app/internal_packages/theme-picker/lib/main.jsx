import React from 'react';
import { Actions, WorkspaceStore } from 'mailspring-exports';

import ThemePicker from './theme-picker';

export function activate() {
  this.disposable = AppEnv.commands.add(document.body, 'window:launch-theme-picker', () => {
    WorkspaceStore.popToRootSheet();
    Actions.openModal({
      component: <ThemePicker />,
      height: 390,
      width: 250,
    });
  });
}

export function deactivate() {
  this.disposable.dispose();
}
