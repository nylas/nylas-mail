/* eslint react/sort-comp: 0 */
import _ from 'underscore';
import React from 'react';
import {remote} from 'electron';

import {
  Message,
  DraftStore,
  ComponentRegistry,
  WorkspaceStore,
} from 'nylas-exports';
import ComposeButton from './compose-button';
import ComposerView from './composer-view';

import InflateDraftClientId from './decorators/inflate-draft-client-id';
const ComposerViewForDraftClientId = InflateDraftClientId(ComposerView);

class ComposerWithWindowProps extends React.Component {
  static displayName = 'ComposerWithWindowProps';
  static containerRequired = false;

  constructor(props) {
    super(props);
    this.state = NylasEnv.getWindowProps()
  }

  componentDidMount() {
    if (this.state.draftClientId) {
      this.ready();
    }

    this.unlisten = NylasEnv.onWindowPropsReceived((windowProps) => {
      const {errorMessage, draftJSON, draftClientId} = windowProps;

      if (draftJSON) {
        const draft = new Message().fromJSON(draftJSON);
        DraftStore._createSession(draftClientId, draft);
      }

      this.setState({draftClientId});
      this.ready();
      if (errorMessage) {
        this._showInitialErrorDialog(errorMessage);
      }
    });
  }

  componentWillUnmount() {
    if (this.unlisten) {
      this.unlisten();
    }
  }

  ready = () => {
    this.refs.composer.focus().then(() => {
      NylasEnv.getCurrentWindow().show()
      NylasEnv.getCurrentWindow().focus()
    });
  }

  render() {
    return (
      <ComposerViewForDraftClientId
        ref="composer"
        draftClientId={this.state.draftClientId}
        className="composer-full-window"
      />
    );
  }

  _showInitialErrorDialog(msg) {
    const dialog = remote.require('dialog');
    // We delay so the view has time to update the restored draft. If we
    // don't delay the modal may come up in a state where the draft looks
    // like it hasn't been restored or has been lost.
    _.delay(() => {
      dialog.showMessageBox(remote.getCurrentWindow(), {
        type: 'warning',
        buttons: ['Okay'],
        message: "Error",
        detail: msg,
      });
    }, 100);
  }
}

export function activate() {
  // Register our composer as the window-wide Composer
  ComponentRegistry.register(ComposerViewForDraftClientId, {
    role: 'Composer',
  });

  if (NylasEnv.isMainWindow()) {
    NylasEnv.registerHotWindow({
      windowType: 'composer',
      replenishNum: 2,
    });
    ComponentRegistry.register(ComposeButton, {
      location: WorkspaceStore.Location.RootSidebar.Toolbar,
    });
  } else {
    NylasEnv.getCurrentWindow().setMinimumSize(480, 250);
    WorkspaceStore.defineSheet('Main', {root: true}, {
      popout: ['Center'],
    });
    ComponentRegistry.register(ComposerWithWindowProps, {
      location: WorkspaceStore.Location.Center,
    });
  }
}

export function deactivate() {
  if (NylasEnv.isMainWindow()) {
    NylasEnv.unregisterHotWindow('composer');
  }
  ComponentRegistry.unregister(ComposerViewForDraftClientId);
  ComponentRegistry.unregister(ComposeButton);
  ComponentRegistry.unregister(ComposerWithWindowProps);
}

export function serialize() {
  return this.state;
}
