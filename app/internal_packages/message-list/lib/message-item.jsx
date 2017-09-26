import React from 'react';
import PropTypes from 'prop-types';
import classNames from 'classnames';
import { Utils, Actions, AttachmentStore } from 'mailspring-exports';
import { RetinaImg, InjectedComponentSet, InjectedComponent } from 'mailspring-component-kit';

import MessageParticipants from './message-participants';
import MessageItemBody from './message-item-body';
import MessageTimestamp from './message-timestamp';
import MessageControls from './message-controls';

export default class MessageItem extends React.Component {
  static displayName = 'MessageItem';

  static propTypes = {
    thread: PropTypes.object.isRequired,
    message: PropTypes.object.isRequired,
    messages: PropTypes.array.isRequired,
    collapsed: PropTypes.bool,
    pending: PropTypes.bool,
    isMostRecent: PropTypes.bool,
    className: PropTypes.string,
  };

  constructor(props, context) {
    super(props, context);

    const fileIds = this.props.message.fileIds();
    this.state = {
      // Holds the downloadData (if any) for all of our files. It's a hash
      // keyed by a fileId. The value is the downloadData.
      downloads: AttachmentStore.getDownloadDataForFiles(fileIds),
      filePreviewPaths: AttachmentStore.previewPathsForFiles(fileIds),
      detailedHeaders: false,
      detailedHeadersTogglePos: { top: 18 },
    };
  }

  componentDidMount() {
    this._storeUnlisten = AttachmentStore.listen(this._onDownloadStoreChange);
    this._setDetailedHeadersTogglePos();
  }

  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.isEqualReact(nextProps, this.props) || !Utils.isEqualReact(nextState, this.state);
  }

  componentDidUpdate() {
    this._setDetailedHeadersTogglePos();
  }

  componentWillUnmount() {
    if (this._storeUnlisten) {
      this._storeUnlisten();
    }
  }

  _onClickParticipants = e => {
    let el = e.target;
    while (el !== e.currentTarget) {
      if (el.classList.contains('collapsed-participants')) {
        this.setState({ detailedHeaders: true });
        e.stopPropagation();
        return;
      }
      el = el.parentElement;
    }
    return;
  };

  _onClickHeader = e => {
    if (this.state.detailedHeaders) {
      return;
    }
    let el = e.target;
    while (el !== e.currentTarget) {
      if (
        el.classList.contains('message-header-right') ||
        el.classList.contains('collapsed-participants')
      ) {
        return;
      }
      el = el.parentElement;
    }
    this._onToggleCollapsed();
  };

  _onDownloadAll = () => {
    Actions.fetchAndSaveAllFiles(this.props.message.files);
  };

  _setDetailedHeadersTogglePos = () => {
    if (!this._headerEl) {
      return;
    }
    const fromNode = this._headerEl.querySelector(
      '.participant-name.from-contact,.participant-primary'
    );
    if (!fromNode) {
      return;
    }
    const fromRect = fromNode.getBoundingClientRect();
    const topPos = Math.floor(fromNode.offsetTop + fromRect.height / 2 - 10);
    if (topPos !== this.state.detailedHeadersTogglePos.top) {
      this.setState({ detailedHeadersTogglePos: { top: topPos } });
    }
  };

  _onToggleCollapsed = () => {
    if (this.props.isMostRecent) {
      return;
    }
    Actions.toggleMessageIdExpanded(this.props.message.id);
  };

  _isRealFile = file => {
    const hasCIDInBody =
      file.contentId !== undefined &&
      this.props.message.body &&
      this.props.message.body.indexOf(file.contentId) > 0;
    return !hasCIDInBody;
  };

  _onDownloadStoreChange = () => {
    const fileIds = this.props.message.fileIds();
    this.setState({
      downloads: AttachmentStore.getDownloadDataForFiles(fileIds),
      filePreviewPaths: AttachmentStore.previewPathsForFiles(fileIds),
    });
  };

  _renderDownloadAllButton() {
    return (
      <div className="download-all">
        <div className="attachment-number">
          <RetinaImg name="ic-attachments-all-clippy.png" mode={RetinaImg.Mode.ContentIsMask} />
          <span>{this.props.message.files.length} attachments</span>
        </div>
        <div className="separator">-</div>
        <div className="download-all-action" onClick={this._onDownloadAll}>
          <RetinaImg name="ic-attachments-download-all.png" mode={RetinaImg.Mode.ContentIsMask} />
          <span>Download all</span>
        </div>
      </div>
    );
  }

  _renderAttachments() {
    const files = (this.props.message.files || []).filter(f => this._isRealFile(f));
    const messageId = this.props.message.id;
    const { filePreviewPaths, downloads } = this.state;
    if (files.length === 0) {
      return <div />;
    }
    return (
      <div>
        {files.length > 1 ? this._renderDownloadAllButton() : null}
        <div className="attachments-area">
          <InjectedComponent
            matching={{ role: 'MessageAttachments' }}
            exposedProps={{
              files,
              downloads,
              filePreviewPaths,
              messageId,
              canRemoveAttachments: false,
            }}
          />
        </div>
      </div>
    );
  }

  _renderFooterStatus() {
    return (
      <InjectedComponentSet
        className="message-footer-status"
        matching={{ role: 'MessageFooterStatus' }}
        exposedProps={{
          message: this.props.message,
          thread: this.props.thread,
          detailedHeaders: this.state.detailedHeaders,
        }}
      />
    );
  }

  _renderHeader() {
    const { message, thread, messages, pending } = this.props;
    const classes = classNames({
      'message-header': true,
      pending: pending,
    });

    return (
      <header
        ref={el => {
          this._headerEl = el;
        }}
        className={classes}
        onClick={this._onClickHeader}
      >
        <InjectedComponent
          matching={{ role: 'MessageHeader' }}
          exposedProps={{ message: message, thread: thread, messages: messages }}
        />
        <div className="pending-spinner" style={{ position: 'absolute', marginTop: -2 }}>
          <RetinaImg width={18} name="sending-spinner.gif" mode={RetinaImg.Mode.ContentPreserve} />
        </div>
        <div className="message-header-right">
          <MessageTimestamp
            className="message-time"
            isDetailed={this.state.detailedHeaders}
            date={message.date}
          />
          <InjectedComponentSet
            className="message-header-status"
            matching={{ role: 'MessageHeaderStatus' }}
            exposedProps={{
              message: message,
              thread: thread,
              detailedHeaders: this.state.detailedHeaders,
            }}
          />
          <MessageControls thread={thread} message={message} />
        </div>
        <MessageParticipants
          from={message.from}
          onClick={this._onClickParticipants}
          isDetailed={this.state.detailedHeaders}
        />
        <MessageParticipants
          to={message.to}
          cc={message.cc}
          bcc={message.bcc}
          onClick={this._onClickParticipants}
          isDetailed={this.state.detailedHeaders}
        />
        {this._renderFolder()}
        {this._renderHeaderDetailToggle()}
      </header>
    );
  }

  _renderHeaderDetailToggle() {
    if (this.props.pending) {
      return null;
    }
    const { top } = this.state.detailedHeadersTogglePos;
    if (this.state.detailedHeaders) {
      return (
        <div
          className="header-toggle-control"
          style={{ top, left: '-14px' }}
          onClick={e => {
            this.setState({ detailedHeaders: false });
            e.stopPropagation();
          }}
        >
          <RetinaImg
            name={'message-disclosure-triangle-active.png'}
            mode={RetinaImg.Mode.ContentIsMask}
          />
        </div>
      );
    }

    return (
      <div
        className="header-toggle-control inactive"
        style={{ top }}
        onClick={e => {
          this.setState({ detailedHeaders: true });
          e.stopPropagation();
        }}
      >
        <RetinaImg name={'message-disclosure-triangle.png'} mode={RetinaImg.Mode.ContentIsMask} />
      </div>
    );
  }

  _renderFolder() {
    if (!this.state.detailedHeaders) {
      return false;
    }

    const folder = this.props.message.folder;
    if (!folder || folder.role === 'al') {
      return false;
    }

    return (
      <div className="header-row">
        <div className="header-label">Folder:&nbsp;</div>
        <div className="header-name">{folder.displayName}</div>
      </div>
    );
  }

  _renderCollapsed() {
    const { message: { snippet, from, files, date, draft }, className } = this.props;

    const attachmentIcon = Utils.showIconForAttachments(files) ? (
      <div className="collapsed-attachment" />
    ) : null;

    return (
      <div className={className} onClick={this._onToggleCollapsed}>
        <div className="message-item-white-wrap">
          <div className="message-item-area">
            <div className="collapsed-from">
              {from && from[0] && from[0].displayName({ compact: true })}
            </div>
            <div className="collapsed-snippet">{snippet}</div>
            {draft && (
              <div className="Collapsed-draft">
                <RetinaImg
                  name="icon-draft-pencil.png"
                  className="draft-icon"
                  mode={RetinaImg.Mode.ContentPreserve}
                />
              </div>
            )}
            <div className="collapsed-timestamp">
              <MessageTimestamp date={date} />
            </div>
            {attachmentIcon}
          </div>
        </div>
      </div>
    );
  }

  _renderFull() {
    return (
      <div className={this.props.className}>
        <div className="message-item-white-wrap">
          <div className="message-item-area">
            {this._renderHeader()}
            <MessageItemBody message={this.props.message} downloads={this.state.downloads} />
            {this._renderAttachments()}
            {this._renderFooterStatus()}
          </div>
        </div>
      </div>
    );
  }

  render() {
    return this.props.collapsed ? this._renderCollapsed() : this._renderFull();
  }
}
