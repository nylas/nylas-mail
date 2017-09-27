import { remote } from 'electron';
import {
  React,
  ReactDOM,
  PropTypes,
  Utils,
  Actions,
  DraftStore,
  AttachmentStore,
  DraftHelpers,
} from 'mailspring-exports';
import {
  DropZone,
  RetinaImg,
  ScrollRegion,
  TabGroupRegion,
  AttachmentItem,
  InjectedComponent,
  KeyCommandsRegion,
  OverlaidComponents,
  ImageAttachmentItem,
  InjectedComponentSet,
} from 'mailspring-component-kit';
import ComposerEditor from './composer-editor';
import ComposerHeader from './composer-header';
import SendActionButton from './send-action-button';
import ActionBarPlugins from './action-bar-plugins';
import Fields from './fields';

// The ComposerView is a unique React component because it (currently) is a
// singleton. Normally, the React way to do things would be to re-render the
// Composer with new props.
export default class ComposerView extends React.Component {
  static displayName = 'ComposerView';

  static propTypes = {
    session: PropTypes.object.isRequired,
    draft: PropTypes.object.isRequired,

    // Sometimes when changes in the composer happens it's desirable to
    // have the parent scroll to a certain location. A parent component can
    // pass a callback that gets called when this composer wants to be
    // scrolled to.
    scrollTo: PropTypes.func,
    className: PropTypes.string,
  };

  constructor(props) {
    super(props);
    this._els = {};
    this.state = {
      showQuotedText: DraftHelpers.isForwardedMessage(props.draft),
      showQuotedTextControl: DraftHelpers.shouldAppendQuotedText(props.draft),
    };
  }

  componentDidMount() {
    if (this.props.session) {
      this._setupForProps(this.props);
    }
  }

  componentWillReceiveProps(nextProps) {
    if (nextProps.session !== this.props.session) {
      this._teardownForProps();
      this._setupForProps(nextProps);
    }
    if (
      DraftHelpers.isForwardedMessage(this.props.draft) !==
        DraftHelpers.isForwardedMessage(nextProps.draft) ||
      DraftHelpers.shouldAppendQuotedText(this.props.draft) !==
        DraftHelpers.shouldAppendQuotedText(nextProps.draft)
    ) {
      this.setState({
        showQuotedText: DraftHelpers.isForwardedMessage(nextProps.draft),
        showQuotedTextControl: DraftHelpers.shouldAppendQuotedText(nextProps.draft),
      });
    }
  }

  componentWillUnmount() {
    this._teardownForProps();
  }

  focus() {
    if (this._els.header.isFocused()) {
      this._els.header.focus();
    } else {
      this._els[Fields.Body].focus();
    }
  }

  _keymapHandlers() {
    return {
      'composer:send-message': () => this._onPrimarySend(),
      'composer:delete-empty-draft': () => {
        if (this.props.draft.pristine) {
          this._onDestroyDraft();
        }
      },
      'composer:show-and-focus-bcc': () => this._els.header.showAndFocusField(Fields.Bcc),
      'composer:show-and-focus-cc': () => this._els.header.showAndFocusField(Fields.Cc),
      'composer:focus-to': () => this._els.header.showAndFocusField(Fields.To),
      'composer:show-and-focus-from': () => {},
      'core:undo': event => {
        event.preventDefault();
        event.stopPropagation();
        this.props.session.undo();
      },
      'core:redo': event => {
        event.preventDefault();
        event.stopPropagation();
        this.props.session.redo();
      },
    };
  }

  _setupForProps({ draft, session }) {
    this.setState({
      showQuotedText: DraftHelpers.isForwardedMessage(draft),
      showQuotedTextControl: DraftHelpers.shouldAppendQuotedText(draft),
    });

    // TODO: This is a dirty hack to save selection state into the undo/redo
    // history. Remove it if / when selection is written into the body with
    // marker tags, or when selection is moved from `contenteditable.innerState`
    // into a first-order part of the session state.

    session._composerViewSelectionRetrieve = () => {
      // Selection updates /before/ the contenteditable emits it's change event,
      // so the selection that goes with the snapshot state is the previous one.
      if (this._els[Fields.Body].getPreviousSelection) {
        return this._els[Fields.Body].getPreviousSelection();
      }
      return null;
    };

    session._composerViewSelectionRestore = selection => {
      this._els[Fields.Body].setSelection(selection);
    };

    draft.files.forEach(file => {
      if (Utils.shouldDisplayAsImage(file)) {
        Actions.fetchFile(file);
      }
    });
  }

  _teardownForProps() {
    if (this.props.session) {
      this.props.session._composerViewSelectionRestore = null;
      this.props.session._composerViewSelectionRetrieve = null;
    }
  }

  _setSREl = el => {
    this._els.scrollregion = el;
  };
  _renderContentScrollRegion() {
    if (AppEnv.isComposerWindow()) {
      return (
        <ScrollRegion
          className="compose-body-scroll"
          ref={el => {
            if (el) {
              this._els.scrollregion = el;
            }
          }}
        >
          {this._renderContent()}
        </ScrollRegion>
      );
    }
    return this._renderContent();
  }

  _onNewHeaderComponents = () => {
    if (this._els.header) {
      this.focus();
    }
  };

  _renderContent() {
    return (
      <div className="composer-centered">
        <ComposerHeader
          ref={el => {
            if (el) {
              this._els.header = el;
            }
          }}
          draft={this.props.draft}
          session={this.props.session}
          initiallyFocused={this.props.draft.to.length === 0}
          onNewHeaderComponents={this._onNewHeaderComponents}
        />
        <div
          className="compose-body"
          ref={el => {
            if (el) {
              this._els.composeBody = el;
            }
          }}
          onMouseUp={this._onMouseUpComposerBody}
          onMouseDown={this._onMouseDownComposerBody}
        >
          {this._renderBodyRegions()}
          {this._renderFooterRegions()}
        </div>
      </div>
    );
  }

  _renderBodyRegions() {
    const exposedProps = {
      draft: this.props.draft,
      session: this.props.session,
    };
    return (
      <div
        ref={el => {
          if (el) {
            this._els.composerBodyWrap = el;
          }
        }}
        className="composer-body-wrap"
      >
        <OverlaidComponents exposedProps={exposedProps}>{this._renderEditor()}</OverlaidComponents>
        {this._renderQuotedTextControl()}
        {this._renderAttachments()}
      </div>
    );
  }

  _renderEditor() {
    const exposedProps = {
      body: this.props.draft.body,
      headerMessageId: this.props.draft.headerMessageId,
      parentActions: {
        getComposerBoundingRect: this._getComposerBoundingRect,
        scrollTo: this.props.scrollTo,
      },
      onFilePaste: this._onFileReceived,
      onBodyChanged: this._onBodyChanged,
    };

    return (
      <InjectedComponent
        ref={el => {
          if (el) {
            this._els[Fields.Body] = el;
          }
        }}
        className="body-field"
        matching={{ role: 'Composer:Editor' }}
        fallback={ComposerEditor}
        requiredMethods={[
          'focus',
          'focusAbsoluteEnd',
          'getPreviousSelection',
          'setSelection',
          '_onDOMMutated',
        ]}
        exposedProps={exposedProps}
      />
    );
  }

  // The contenteditable decides when to request a scroll based on the
  // position of the cursor and its relative distance to this composer
  // component. We provide it our boundingClientRect so it can calculate
  // this value.
  _getComposerBoundingRect = () => {
    return ReactDOM.findDOMNode(this._els.composerWrap).getBoundingClientRect();
  };

  _renderQuotedTextControl() {
    if (this.state.showQuotedTextControl) {
      return (
        <a className="quoted-text-control" onClick={this._onExpandQuotedText}>
          <span className="dots">&bull;&bull;&bull;</span>
          <span className="remove-quoted-text" onClick={this._onRemoveQuotedText}>
            <RetinaImg
              title="Remove quoted text"
              name="image-cancel-button.png"
              mode={RetinaImg.Mode.ContentPreserve}
            />
          </span>
        </a>
      );
    }
    return false;
  }

  _onExpandQuotedText = () => {
    this.setState(
      {
        showQuotedText: true,
        showQuotedTextControl: false,
      },
      () => {
        DraftHelpers.appendQuotedTextToDraft(this.props.draft).then(draftWithQuotedText => {
          this.props.session.changes.add({
            body: `${draftWithQuotedText.body}<div id="mailspring-quoted-text-marker" />`,
          });
        });
      }
    );
  };

  _onRemoveQuotedText = event => {
    event.stopPropagation();
    const { session, draft } = this.props;
    session.changes.add({
      body: `${draft.body}<div id="mailspring-quoted-text-marker" />`,
    });
    this.setState({
      showQuotedText: false,
      showQuotedTextControl: false,
    });
  };

  _renderFooterRegions() {
    return (
      <div className="composer-footer-region">
        <InjectedComponentSet
          matching={{ role: 'Composer:Footer' }}
          exposedProps={{
            draft: this.props.draft,
            threadId: this.props.draft.threadId,
            headerMessageId: this.props.draft.headerMessageId,
            session: this.props.session,
          }}
          direction="column"
        />
      </div>
    );
  }

  _renderAttachments() {
    const { files, headerMessageId } = this.props.draft;

    const nonImageFiles = files
      .filter(f => !Utils.shouldDisplayAsImage(f))
      .map(file => (
        <AttachmentItem
          key={file.id}
          className="file-upload"
          draggable={false}
          filePath={AttachmentStore.pathForFile(file)}
          displayName={file.filename}
          fileIconName={`file-${file.extension}.png`}
          onRemoveAttachment={() => Actions.removeAttachment(headerMessageId, file)}
        />
      ));
    const imageFiles = files
      .filter(f => Utils.shouldDisplayAsImage(f))
      .filter(f => !f.contentId)
      .map(file => (
        <ImageAttachmentItem
          key={file.id}
          className="file-upload"
          draggable={false}
          filePath={AttachmentStore.pathForFile(file)}
          displayName={file.filename}
          onRemoveAttachment={() => Actions.removeAttachment(headerMessageId, file)}
        />
      ));

    return <div className="attachments-area">{nonImageFiles.concat(imageFiles)}</div>;
  }

  _renderActionsWorkspaceRegion() {
    return (
      <InjectedComponentSet
        matching={{ role: 'Composer:ActionBarWorkspace' }}
        exposedProps={{
          draft: this.props.draft,
          threadId: this.props.draft.threadId,
          headerMessageId: this.props.draft.headerMessageId,
          session: this.props.session,
        }}
      />
    );
  }

  _renderActionsRegion() {
    return (
      <div className="composer-action-bar-content">
        <ActionBarPlugins
          draft={this.props.draft}
          session={this.props.session}
          isValidDraft={this._isValidDraft}
        />

        <button
          tabIndex={-1}
          className="btn btn-toolbar btn-trash"
          style={{ order: 100 }}
          title="Delete draft"
          onClick={this._onDestroyDraft}
        >
          <RetinaImg name="icon-composer-trash.png" mode={RetinaImg.Mode.ContentIsMask} />
        </button>

        <button
          tabIndex={-1}
          className="btn btn-toolbar btn-attach"
          style={{ order: 50 }}
          title="Attach file"
          onClick={this._onSelectAttachment}
        >
          <RetinaImg name="icon-composer-attachment.png" mode={RetinaImg.Mode.ContentIsMask} />
        </button>

        <div style={{ order: 0, flex: 1 }} />

        <InjectedComponent
          ref={el => {
            if (el) {
              this._els.sendActionButton = el;
            }
          }}
          tabIndex={-1}
          style={{ order: -100 }}
          matching={{ role: 'Composer:SendActionButton' }}
          fallback={SendActionButton}
          requiredMethods={['primarySend']}
          exposedProps={{
            draft: this.props.draft,
            headerMessageId: this.props.draft.headerMessageId,
            session: this.props.session,
            isValidDraft: this._isValidDraft,
          }}
        />
      </div>
    );
  }

  // This lets us click outside of the `contenteditable`'s `contentBody`
  // and simulate what happens when you click beneath the text *in* the
  // contentEditable.

  // Unfortunately, we need to manually keep track of the "click" in
  // separate mouseDown, mouseUp events because we need to ensure that the
  // start and end target are both not in the contenteditable. This ensures
  // that this behavior doesn't interfear with a click and drag selection.
  _onMouseDownComposerBody = event => {
    if (ReactDOM.findDOMNode(this._els[Fields.Body]).contains(event.target)) {
      this._mouseDownTarget = null;
    } else {
      this._mouseDownTarget = event.target;
    }
  };

  _inFooterRegion(el) {
    return el.closest && el.closest('.composer-footer-region, .overlaid-components');
  }

  _onMouseUpComposerBody = event => {
    if (event.target === this._mouseDownTarget && !this._inFooterRegion(event.target)) {
      // We don't set state directly here because we want the native
      // contenteditable focus behavior. When the contenteditable gets focused
      const bodyRect = ReactDOM.findDOMNode(this._els[Fields.Body]).getBoundingClientRect();
      if (event.pageY < bodyRect.top) {
        this._els[Fields.Body].focus();
      } else {
        this._els[Fields.Body].focusAbsoluteEnd();
      }
    }
    this._mouseDownTarget = null;
  };

  _onMouseMoveComposeBody = () => {
    if (this._mouseComposeBody === 'down') {
      this._mouseComposeBody = 'move';
    }
  };

  _shouldAcceptDrop = event => {
    // Ensure that you can't pick up a file and drop it on the same draft
    const nonNativeFilePath = this._nonNativeFilePathForDrop(event);

    const hasNativeFile = event.dataTransfer.types.includes('Files');
    const hasNonNativeFilePath = nonNativeFilePath !== null;

    return hasNativeFile || hasNonNativeFilePath;
  };

  _nonNativeFilePathForDrop = event => {
    if (event.dataTransfer.types.includes('text/nylas-file-url')) {
      const downloadURL = event.dataTransfer.getData('text/nylas-file-url');
      const downloadFilePath = downloadURL.split('file://')[1];
      if (downloadFilePath) {
        return downloadFilePath;
      }
    }

    // Accept drops of images from within the app
    if (event.dataTransfer.types.includes('text/uri-list')) {
      const uri = event.dataTransfer.getData('text/uri-list');
      if (uri.indexOf('file://') === 0) {
        return decodeURI(uri.split('file://')[1]);
      }
    }
    return null;
  };

  _onDrop = event => {
    // Accept drops of real files from other applications
    for (const file of Array.from(event.dataTransfer.files)) {
      this._onFileReceived(file.path);
    }

    // Accept drops from attachment components / images within the app
    const uri = this._nonNativeFilePathForDrop(event);
    if (uri) {
      this._onFileReceived(uri);
    }
  };

  _onFileReceived = filePath => {
    // called from onDrop and onFilePaste - assume images should be inline
    Actions.addAttachment({
      filePath: filePath,
      headerMessageId: this.props.draft.headerMessageId,
      onCreated: file => {
        if (Utils.shouldDisplayAsImage(file)) {
          const { draft, session } = this.props;
          const match = draft.files.find(f => f.id === file.id);
          if (!match) {
            return;
          }

          match.contentId = Utils.generateTempId();
          session.changes.add({
            files: [].concat(draft.files),
          });
          Actions.insertAttachmentIntoDraft({
            headerMessageId: draft.headerMessageId,
            fileId: match.id,
          });
        }
      },
    });
  };

  _onBodyChanged = event => {
    this.props.session.changes.add({ body: event.target.value });
    return;
  };

  _isValidDraft = (options = {}) => {
    // We need to check the `DraftStore` because the `DraftStore` is
    // immediately and synchronously updated as soon as this function
    // fires. Since `setState` is asynchronous, if we used that as our only
    // check, then we might get a false reading.
    if (DraftStore.isSendingDraft(this.props.draft.headerMessageId)) {
      return false;
    }

    const dialog = remote.dialog;
    const { session } = this.props;
    const { errors, warnings } = session.validateDraftForSending();

    if (errors.length > 0) {
      dialog.showMessageBox(remote.getCurrentWindow(), {
        type: 'warning',
        buttons: ['Edit Message', 'Cancel'],
        message: 'Cannot Send',
        detail: errors[0],
      });
      return false;
    }

    if (warnings.length > 0 && !options.force) {
      const response = dialog.showMessageBox(remote.getCurrentWindow(), {
        type: 'warning',
        buttons: ['Send Anyway', 'Cancel'],
        message: 'Are you sure?',
        detail: `Send ${warnings.join(' and ')}?`,
      });
      if (response === 0) {
        // response is button array index
        return this._isValidDraft({ force: true });
      }
      return false;
    }
    return true;
  };

  _onPrimarySend = () => {
    this._els.sendActionButton.primarySend();
  };

  _onDestroyDraft = () => {
    Actions.destroyDraft(this.props.draft);
  };

  _onSelectAttachment = () => {
    Actions.selectAttachment({ headerMessageId: this.props.draft.headerMessageId });
  };

  render() {
    const dropCoverDisplay = this.state.isDropping ? 'block' : 'none';

    return (
      <div className={this.props.className}>
        <KeyCommandsRegion
          localHandlers={this._keymapHandlers()}
          className={'message-item-white-wrap composer-outer-wrap'}
          ref={el => {
            if (el) {
              this._els.composerWrap = el;
            }
          }}
          tabIndex="-1"
        >
          <TabGroupRegion className="composer-inner-wrap">
            <DropZone
              className="composer-inner-wrap"
              shouldAcceptDrop={this._shouldAcceptDrop}
              onDragStateChange={({ isDropping }) => this.setState({ isDropping })}
              onDrop={this._onDrop}
            >
              <div className="composer-drop-cover" style={{ display: dropCoverDisplay }}>
                <div className="centered">
                  <RetinaImg
                    name="composer-drop-to-attach.png"
                    mode={RetinaImg.Mode.ContentIsMask}
                  />
                  Drop to attach
                </div>
              </div>

              <div className="composer-content-wrap">{this._renderContentScrollRegion()}</div>

              <div className="composer-action-bar-workspace-wrap">
                {this._renderActionsWorkspaceRegion()}
              </div>

              <div className="composer-action-bar-wrap" data-tooltips-anchor>
                <div className="tooltips-container" />
                {this._renderActionsRegion()}
              </div>
            </DropZone>
          </TabGroupRegion>
        </KeyCommandsRegion>
      </div>
    );
  }
}
