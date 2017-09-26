/* eslint react/sort-comp: 0 */
import _ from 'underscore';
import React from 'react';
import {
  Message,
  DraftStore,
  WorkspaceStore,
  ComponentRegistry,
  ExtensionRegistry,
  InflatesDraftClientId,
  CustomContenteditableComponents,
} from 'mailspring-exports';
import { OverlaidComposerExtension } from 'mailspring-component-kit';
import ComposeButton from './compose-button';
import ComposerView from './composer-view';
import InlineImageComposerExtension from './inline-image-composer-extension';
import InlineImageUploadContainer from './inline-image-upload-container';

const ComposerViewForDraftClientId = InflatesDraftClientId(ComposerView);

class ComposerWithWindowProps extends React.Component {
  static displayName = 'ComposerWithWindowProps';
  static containerRequired = false;

  constructor(props) {
    super(props);

    // We'll now always have windowProps by the time we construct this.
    const windowProps = AppEnv.getWindowProps();
    const { draftJSON, headerMessageId } = windowProps;
    if (!draftJSON) {
      throw new Error('Initialize popout composer windows with valid draftJSON');
    }
    const draft = new Message().fromJSON(draftJSON);
    DraftStore._createSession(headerMessageId, draft);
    this.state = windowProps;
  }

  componentWillUnmount() {
    if (this._usub) {
      this._usub();
    }
  }

  componentDidUpdate() {
    this._composerComponent.focus();
  }

  _onDraftReady = () => {
    this._composerComponent.focus().then(() => {
      AppEnv.displayWindow();

      if (this.state.errorMessage) {
        this._showInitialErrorDialog(this.state.errorMessage, this.state.errorDetail);
      }
    });
  };

  render() {
    return (
      <ComposerViewForDraftClientId
        ref={cm => {
          this._composerComponent = cm;
        }}
        onDraftReady={this._onDraftReady}
        headerMessageId={this.state.headerMessageId}
        className="composer-full-window"
      />
    );
  }

  _showInitialErrorDialog(msg, detail) {
    // We delay so the view has time to update the restored draft. If we
    // don't delay the modal may come up in a state where the draft looks
    // like it hasn't been restored or has been lost.
    _.delay(() => {
      AppEnv.showErrorDialog({ title: 'Error', message: msg }, { detail: detail });
    }, 100);
  }
}

export function activate() {
  if (AppEnv.isMainWindow()) {
    ComponentRegistry.register(ComposerViewForDraftClientId, {
      role: 'Composer',
    });
    ComponentRegistry.register(ComposeButton, {
      location: WorkspaceStore.Location.RootSidebar.Toolbar,
    });
  } else if (AppEnv.isThreadWindow()) {
    ComponentRegistry.register(ComposerViewForDraftClientId, {
      role: 'Composer',
    });
  } else {
    AppEnv.getCurrentWindow().setMinimumSize(480, 250);
    ComponentRegistry.register(ComposerWithWindowProps, {
      location: WorkspaceStore.Location.Center,
    });
  }

  ExtensionRegistry.Composer.register(OverlaidComposerExtension, { priority: 1 });
  ExtensionRegistry.Composer.register(InlineImageComposerExtension);
  CustomContenteditableComponents.register(
    'InlineImageUploadContainer',
    InlineImageUploadContainer
  );
}

export function deactivate() {
  if (AppEnv.isMainWindow()) {
    ComponentRegistry.unregister(ComposerViewForDraftClientId);
    ComponentRegistry.unregister(ComposeButton);
  } else {
    ComponentRegistry.unregister(ComposerWithWindowProps);
  }

  ExtensionRegistry.Composer.unregister(OverlaidComposerExtension);
  ExtensionRegistry.Composer.unregister(InlineImageComposerExtension);
  CustomContenteditableComponents.unregister('InlineImageUploadContainer');
}

export function serialize() {
  return this.state;
}
