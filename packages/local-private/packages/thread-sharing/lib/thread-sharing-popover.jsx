/* eslint jsx-a11y/tabindex-no-positive: 0 */
import React from 'react'
import ReactDOM from 'react-dom'
import classnames from 'classnames';
import {Rx, Actions, NylasAPIHelpers, Thread, DatabaseStore} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';

import CopyButton from './copy-button';
import {PLUGIN_ID, PLUGIN_NAME, PLUGIN_URL} from './thread-sharing-constants';


function isShared(thread) {
  const metadata = thread.metadataForPluginId(PLUGIN_ID) || {};
  return metadata.shared || false;
}

export default class ThreadSharingPopover extends React.Component {
  static propTypes = {
    thread: React.PropTypes.object,
    accountId: React.PropTypes.string,
  }

  constructor(props) {
    super(props);
    this.state = {
      shared: isShared(props.thread),
      saving: false,
    }
    this._disposable = {dispose: () => {}}
  }

  componentDidMount() {
    const {thread} = this.props;
    this._mounted = true;
    this._disposable = Rx.Observable.fromQuery(DatabaseStore.find(Thread, thread.id))
    .subscribe((t) => this.setState({shared: isShared(t)}))
  }

  componentDidUpdate() {
    ReactDOM.findDOMNode(this).focus()
  }

  componentWillUnmount() {
    this._disposable.dispose();
    this._mounted = false;
  }

  _onToggleShared = () => {
    const {thread, accountId} = this.props;
    const {shared} = this.state;

    this.setState({saving: true});

    NylasAPIHelpers.authPlugin(PLUGIN_ID, PLUGIN_NAME, accountId)
    .then(() => {
      if (!this._mounted) { return; }
      if (!shared === true) {
        Actions.recordUserEvent("Thread Sharing Enabled", {accountId, threadId: thread.id})
      }
      Actions.setMetadata(thread, PLUGIN_ID, {shared: !shared})
    })
    .catch((error) => {
      NylasEnv.reportError(error);
      NylasEnv.showErrorDialog(`Sorry, we were unable to update your sharing settings.\n\n${error.message}`)
    })
    .finally(() => {
      if (!this._mounted) { return; }
      this.setState({saving: false})
    });
  }

  _onClickInput = (event) => {
    const input = event.target
    input.select()
  }

  render() {
    const {thread, accountId} = this.props;
    const {shared, saving} = this.state;

    const url = `${PLUGIN_URL}/thread/${accountId}/${thread.id}`
    const shareMessage = shared ? 'Anyone with the link can read the thread' : 'Sharing is disabled';
    const classes = classnames({
      'thread-sharing-popover': true,
      'disabled': !shared,
    })

    const control = saving ? (
      <RetinaImg
        style={{width: 14, height: 14, marginBottom: 3, marginRight: 4}}
        name="inline-loading-spinner.gif"
        mode={RetinaImg.Mode.ContentPreserve}
      />
    ) : (
      <input
        type="checkbox"
        id="shareCheckbox"
        checked={shared}
        onChange={this._onToggleShared}
      />
  );

    // tabIndex is necessary for the popover's onBlur events to work properly
    return (
      <div tabIndex="1" className={classes}>
        <div className="share-toggle">
          <label htmlFor="shareCheckbox">
            {control}
            Share this thread
          </label>
        </div>
        <div className="share-input">
          <input
            ref="urlInput"
            id="urlInput"
            type="text"
            value={url}
            readOnly
            disabled={!shared}
            onClick={this._onClickInput}
          />
        </div>
        <div className={`share-controls`}>
          <div className="share-message">{shareMessage}</div>
          <button href={url} className="btn" disabled={!shared}>
            Open in browser
          </button>
          <CopyButton
            className="btn"
            disabled={!shared}
            copyValue={url}
            btnLabel="Copy link"
          />
        </div>
      </div>
    )
  }
}
