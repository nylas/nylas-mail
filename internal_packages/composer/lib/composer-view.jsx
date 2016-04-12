import _ from 'underscore';
import React from 'react';
import ReactDOM from 'react-dom';

import {
  Utils,
  Actions,
  DraftStore,
  UndoManager,
  ContactStore,
  QuotedHTMLTransformer,
  FileDownloadStore,
  ExtensionRegistry,
} from 'nylas-exports';

import {
  DropZone,
  RetinaImg,
  ScrollRegion,
  TabGroupRegion,
  InjectedComponent,
  KeyCommandsRegion,
  InjectedComponentSet,
} from 'nylas-component-kit';

import FileUpload from './file-upload';
import ImageFileUpload from './image-file-upload';

import ComposerEditor from './composer-editor';
import SendActionButton from './send-action-button';
import ComposerHeader from './composer-header';

import Fields from './fields';

// The ComposerView is a unique React component because it (currently) is a
// singleton. Normally, the React way to do things would be to re-render the
// Composer with new props.
export default class ComposerView extends React.Component {
  static displayName = 'ComposerView';

  static propTypes = {
    session: React.PropTypes.object.isRequired,
    draft: React.PropTypes.object.isRequired,

    // Sometimes when changes in the composer happens it's desirable to
    // have the parent scroll to a certain location. A parent component can
    // pass a callback that gets called when this composer wants to be
    // scrolled to.
    scrollTo: React.PropTypes.func,
    className: React.PropTypes.string,
  }

  constructor(props) {
    super(props)
    this.state = {
      showQuotedText: false,
    }
  }

  componentDidMount() {
    if (this.props.session) {
      this._receivedNewSession();
    }
  }

  componentWillReceiveProps(newProps) {
    if (newProps.session !== this.props.session) {
      this._receivedNewSession();
    }
  }

  componentDidUpdate() {
    // We want to use a temporary variable instead of putting this into the
    // state. This is because the selection is a transient property that
    // only needs to be applied once. It's not a long-living property of
    // the state. We could call `setState` here, but this saves us from a
    // re-rendering.
    if (this._recoveredSelection) {
      this._recoveredSelection = null;
    }
  }

  focus() {
    if (ReactDOM.findDOMNode(this).contains(document.activeElement)) {
      return;
    }

    if (this.props.draft.to.length === 0) {
      this.refs.header.showAndFocusField(Fields.To);
    } else if ((this.props.draft.subject || "").trim().length === 0) {
      this.refs.header.showAndFocusField(Fields.Subject);
    } else {
      this.refs[Fields.Body].focus();
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
      'composer:show-and-focus-bcc': () => this.refs.header.showAndFocusField(Fields.Bcc),
      'composer:show-and-focus-cc': () => this.refs.header.showAndFocusField(Fields.Cc),
      'composer:focus-to': () => this.refs.header.showAndFocusField(Fields.To),
      "composer:show-and-focus-from": () => {}, // todo
      "composer:undo": this.undo,
      "composer:redo": this.redo,
    };
  }

  _receivedNewSession() {
    this.undoManager = new UndoManager();
    this._saveToHistory();

    this.setState({
      showQuotedText: Utils.isForwardedMessage(this.props.draft),
    });

    this.props.draft.files.forEach((file) => {
      if (Utils.shouldDisplayAsImage(file)) {
        Actions.fetchFile(file);
      }
    });
  }

  _renderContentScrollRegion() {
    if (NylasEnv.isComposerWindow()) {
      return (
        <ScrollRegion className="compose-body-scroll" ref="scrollregion">
          {this._renderContent()}
        </ScrollRegion>
      );
    }
    return this._renderContent();
  }

  _renderContent() {
    return (
      <div className="composer-centered">
        <ComposerHeader
          ref="header"
          draft={this.props.draft}
          session={this.props.session}
        />
        <div
          className="compose-body"
          ref="composeBody"
          onMouseUp={this._onMouseUpComposerBody}
          onMouseDown={this._onMouseDownComposerBody}>
          {this._renderBodyRegions()}
          {this._renderFooterRegions()}
        </div>
      </div>
    );
  }

  _renderBodyRegions() {
    return (
      <span ref="composerBodyWrap">
        {this._renderEditor()}
        {this._renderQuotedTextControl()}
        {this._renderAttachments()}
      </span>
    );
  }

  _renderEditor() {
    const exposedProps = {
      body: this._removeQuotedText(this.props.draft.body),
      draftClientId: this.props.draft.clientId,
      parentActions: {
        getComposerBoundingRect: this._getComposerBoundingRect,
        scrollTo: this.props.scrollTo,
      },
      initialSelectionSnapshot: this._recoveredSelection,
      onFilePaste: this._onFilePaste,
      onBodyChanged: this._onBodyChanged,
    };

    // TODO Get rid of the unecessary required methods:
    // getCurrentSelection and getPreviousSelection shouldn't be needed and
    // undo/redo functionality should be refactored into ComposerEditor
    // _onDOMMutated === just for testing purposes, refactor the tests
    return (
      <InjectedComponent
        ref={Fields.Body}
        matching={{role: "Composer:Editor"}}
        fallback={ComposerEditor}
        requiredMethods={[
          'focus',
          'focusAbsoluteEnd',
          'getCurrentSelection',
          'getPreviousSelection',
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
    return ReactDOM.findDOMNode(this.refs.composerWrap).getBoundingClientRect()
  }

  _removeQuotedText = (html) => {
    const {showQuotedText} = this.state;
    return showQuotedText ? html : QuotedHTMLTransformer.removeQuotedHTML(html);
  }

  _showQuotedText = (html) => {
    const {showQuotedText} = this.state;
    return showQuotedText ? html : QuotedHTMLTransformer.appendQuotedHTML(html, this.props.draft.body);
  }

  _renderQuotedTextControl() {
    if (QuotedHTMLTransformer.hasQuotedHTML(this.props.draft.body)) {
      return (
        <a className="quoted-text-control" onClick={this._onToggleQuotedText}>
          <span className="dots">&bull;&bull;&bull;</span>
        </a>
      );
    }
    return false;
  }

  _onToggleQuotedText = () => {
    this.setState({showQuotedText: !this.state.showQuotedText});
  }

  _renderFooterRegions() {
    return (
      <div className="composer-footer-region">
        <InjectedComponentSet
          matching={{role: "Composer:Footer"}}
          exposedProps={{draftClientId: this.props.draft.clientId, threadId: this.props.draft.threadId}}
          direction="column"/>
      </div>
    );
  }

  _renderAttachments() {
    return (
      <div className="attachments-area">
        {this._renderFileAttachments()}
        {this._renderUploadAttachments()}
      </div>
    );
  }

  _renderFileAttachments() {
    const {files} = this.props.draft;
    const nonImageFiles = this._nonImageFiles(files).map(file =>
      this._renderFileAttachment(file, "Attachment")
    );
    const imageFiles = this._imageFiles(files).map(file =>
      this._renderFileAttachment(file, "Attachment:Image")
    );
    return nonImageFiles.concat(imageFiles);
  }

  _renderFileAttachment(file, role) {
    const props = {
      file: file,
      removable: true,
      targetPath: FileDownloadStore.pathForFile(file),
      messageClientId: this.props.draft.clientId,
    };

    const className = (role === "Attachment") ? "file-wrap" : "file-wrap file-image-wrap";

    return (
      <InjectedComponent
        key={file.id}
        matching={{role}}
        className={className}
        exposedProps={props}
      />
    );
  }

  _renderUploadAttachments() {
    const {uploads} = this.props.draft;

    const nonImageUploads = this._nonImageFiles(uploads).map(upload =>
      <FileUpload key={upload.id} upload={upload} />
    );
    const imageUploads = this._imageFiles(uploads).map(upload =>
      <ImageFileUpload key={upload.id} upload={upload} />
    );
    return nonImageUploads.concat(imageUploads);
  }

  _imageFiles(files) {
    return _.filter(files, Utils.shouldDisplayAsImage);
  }

  _nonImageFiles(files) {
    return _.reject(files, Utils.shouldDisplayAsImage);
  }

  _renderActionsRegion() {
    return (
      <div className="composer-action-bar-content">
        <InjectedComponentSet
          className="composer-action-bar-plugins"
          matching={{role: "Composer:ActionButton"}}
          exposedProps={{draftClientId: this.props.draft.clientId, threadId: this.props.draft.threadId}} />

        <button
          tabIndex={-1}
          className="btn btn-toolbar btn-trash"
          style={{order: 100}}
          title="Delete draft"
          onClick={this._onDestroyDraft}>
          <RetinaImg name="icon-composer-trash.png" mode={RetinaImg.Mode.ContentIsMask} />
        </button>

        <button
          tabIndex={-1}
          className="btn btn-toolbar btn-attach"
          style={{order: 50}}
          title="Attach file"
          onClick={this._onSelectAttachment}>
          <RetinaImg name="icon-composer-attachment.png" mode={RetinaImg.Mode.ContentIsMask} />
        </button>

        <div style={{order: 0, flex: 1}} />

        <SendActionButton
          tabIndex={-1}
          draft={this.props.draft}
          ref="sendActionButton"
          isValidDraft={this._isValidDraft}
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
  _onMouseDownComposerBody = (event) => {
    if (ReactDOM.findDOMNode(this.refs[Fields.Body]).contains(event.target)) {
      this._mouseDownTarget = null;
    } else {
      this._mouseDownTarget = event.target;
    }
  }

  _inFooterRegion(el) {
    return el.closest && el.closest(".composer-footer-region")
  }

  _onMouseUpComposerBody = (event) => {
    if (event.target === this._mouseDownTarget && !this._inFooterRegion(event.target)) {
      // We don't set state directly here because we want the native
      // contenteditable focus behavior. When the contenteditable gets focused
      // the focused field state will be properly set via editor.onFocus
      this.refs[Fields.Body].focusAbsoluteEnd();
    }
    this._mouseDownTarget = null;
  }

  _onMouseMoveComposeBody = () => {
    if (this._mouseComposeBody === "down") {
      this._mouseComposeBody = "move";
    }
  }

  _shouldAcceptDrop = (event) => {
    // Ensure that you can't pick up a file and drop it on the same draft
    const nonNativeFilePath = this._nonNativeFilePathForDrop(event);

    const hasNativeFile = event.dataTransfer.files.length > 0;
    const hasNonNativeFilePath = nonNativeFilePath !== null;

    return hasNativeFile || hasNonNativeFilePath;
  }

  _nonNativeFilePathForDrop = (event) => {
    if (event.dataTransfer.types.includes("text/nylas-file-url")) {
      const downloadURL = event.dataTransfer.getData("text/nylas-file-url");
      const downloadFilePath = downloadURL.split('file://')[1];
      if (downloadFilePath) {
        return downloadFilePath;
      }
    }

    // Accept drops of images from within the app
    if (event.dataTransfer.types.includes("text/uri-list")) {
      const uri = event.dataTransfer.getData('text/uri-list')
      if (uri.indexOf('file://') === 0) {
        return decodeURI(uri.split('file://')[1]);
      }
    }
    return null;
  }

  _onDrop = (event) => {
    const {clientId} = this.props.draft;

    // Accept drops of real files from other applications
    for (const file of Array.from(event.dataTransfer.files)) {
      Actions.addAttachment({filePath: file.path, messageClientId: clientId});
    }

    // Accept drops from attachment components / images within the app
    const uri = this._nonNativeFilePathForDrop(event);
    if (uri) {
      Actions.addAttachment({filePath: uri, messageClientId: clientId});
    }
  }

  _onFilePaste = (path) => {
    Actions.addAttachment({filePath: path, messageClientId: this.props.draft.clientId});
  }

  _onBodyChanged = (event) => {
    this._addToProxy({body: this._showQuotedText(event.target.value)});
    return;
  }

  _addToProxy = (changes = {}, source = {}) => {
    const selections = this._getSelections();
    this.props.session.changes.add(changes);

    if (!source.fromUndoManager) {
      this._saveToHistory(selections);
    }
  }

  _isValidDraft = (options = {}) => {
    // We need to check the `DraftStore` because the `DraftStore` is
    // immediately and synchronously updated as soon as this function
    // fires. Since `setState` is asynchronous, if we used that as our only
    // check, then we might get a false reading.
    if (DraftStore.isSendingDraft(this.props.draft.clientId)) {
      return false;
    }

    const {remote} = require('electron');
    const dialog = remote.require('dialog');

    const {to, cc, bcc, body, files, uploads} = this.props.draft;
    const allRecipients = [].concat(to, cc, bcc);
    let dealbreaker = null;

    for (const contact of allRecipients) {
      if (!ContactStore.isValidContact(contact)) {
        dealbreaker = `${contact.email} is not a valid email address - please remove or edit it before sending.`
      }
    }
    if (allRecipients.length === 0) {
      dealbreaker = 'You need to provide one or more recipients before sending the message.';
    }

    if (dealbreaker) {
      dialog.showMessageBox(remote.getCurrentWindow(), {
        type: 'warning',
        buttons: ['Edit Message', 'Cancel'],
        message: 'Cannot Send',
        detail: dealbreaker,
      });
      return false;
    }

    const bodyIsEmpty = body === this.props.session.draftPristineBody();
    const forwarded = Utils.isForwardedMessage(this.props.draft);
    const hasAttachment = (files || []).length > 0 || (uploads || []).length > 0;

    let warnings = [];

    if (this.props.draft.subject.length === 0) {
      warnings.push('without a subject line');
    }

    if (this._mentionsAttachment(this.props.draft.body) && !hasAttachment) {
      warnings.push('without an attachment');
    }

    if (bodyIsEmpty && !forwarded && !hasAttachment) {
      warnings.push('without a body');
    }

    // Check third party warnings added via Composer extensions
    for (const extension of ExtensionRegistry.Composer.extensions()) {
      if (!extension.warningsForSending) {
        continue;
      }
      warnings = warnings.concat(extension.warningsForSending({draft: this.props.draft}));
    }

    if ((warnings.length > 0) && (!options.force)) {
      const response = dialog.showMessageBox(remote.getCurrentWindow(), {
        type: 'warning',
        buttons: ['Send Anyway', 'Cancel'],
        message: 'Are you sure?',
        detail: `Send ${warnings.join(' and ')}?`,
      });
      if (response === 0) { // response is button array index
        return this._isValidDraft({force: true});
      }
      return false;
    }

    return true;
  }

  _onPrimarySend = () => {
    this.refs.sendActionButton.primaryClick();
  }

  _onDestroyDraft = () => {
    Actions.destroyDraft(this.props.draft.clientId);
  }

  _onSelectAttachment = () => {
    Actions.selectAttachment({messageClientId: this.props.draft.clientId});
  }

  _mentionsAttachment = (body) => {
    let cleaned = QuotedHTMLTransformer.removeQuotedHTML(body.toLowerCase().trim());
    const signatureIndex = cleaned.indexOf('<signature>');
    if (signatureIndex !== -1) {
      cleaned = cleaned.substr(0, signatureIndex - 1);
    }
    return (cleaned.indexOf("attach") >= 0);
  }

  undo = (event) => {
    event.preventDefault();
    event.stopPropagation();

    const historyItem = this.undoManager.undo() || {};
    if (!historyItem.state) {
      return;
    }

    this._recoveredSelection = historyItem.currentSelection;
    this._addToProxy(historyItem.state, {fromUndoManager: true});
    this._recoveredSelection = null;
  }

  redo = (event) => {
    event.preventDefault();
    event.stopPropagation();
    const historyItem = this.undoManager.redo() || {}
    if (!historyItem.state) {
      return;
    }
    this._recoveredSelection = historyItem.currentSelection;
    this._addToProxy(historyItem.state, {fromUndoManager: true});
    this._recoveredSelection = null;
  }

  _getSelections = () => {
    const bodyComponent = this.refs[Fields.Body];
    return {
      currentSelection: bodyComponent.getCurrentSelection ? bodyComponent.getCurrentSelection() : null,
      previousSelection: bodyComponent.getPreviousSelection ? bodyComponent.getPreviousSelection() : null,
    }
  }

  _saveToHistory = (selections) => {
    const {previousSelection, currentSelection} = selections || this._getSelections();

    const historyItem = {
      previousSelection,
      currentSelection,
      state: {
        body: _.clone(this.props.draft.body),
        subject: _.clone(this.props.draft.subject),
        to: _.clone(this.props.draft.to),
        cc: _.clone(this.props.draft.cc),
        bcc: _.clone(this.props.draft.bcc),
      },
    }

    const lastState = this.undoManager.current()
    if (lastState) {
      lastState.currentSelection = historyItem.previousSelection;
    }

    this.undoManager.saveToHistory(historyItem);
  }

  render() {
    const dropCoverDisplay = this.state.isDropping ? 'block' : 'none';

    return (
      <div className={this.props.className}>
        <KeyCommandsRegion
          localHandlers={this._keymapHandlers()}
          className={"message-item-white-wrap composer-outer-wrap"}
          tabIndex="-1"
          ref="composerWrap">
          <TabGroupRegion className="composer-inner-wrap">
            <DropZone
              className="composer-inner-wrap"
              shouldAcceptDrop={this._shouldAcceptDrop}
              onDragStateChange={ ({isDropping}) => this.setState({isDropping}) }
              onDrop={this._onDrop}>
              <div className="composer-drop-cover" style={{display: dropCoverDisplay}}>
                <div className="centered">
                  <RetinaImg
                    name="composer-drop-to-attach.png"
                    mode={RetinaImg.Mode.ContentIsMask}/>
                  Drop to attach
                </div>
              </div>

              <div className="composer-content-wrap">
                {this._renderContentScrollRegion()}
              </div>

              <div className="composer-action-bar-wrap">
                {this._renderActionsRegion()}
              </div>
            </DropZone>
          </TabGroupRegion>
        </KeyCommandsRegion>
      </div>
    );
  }
}
