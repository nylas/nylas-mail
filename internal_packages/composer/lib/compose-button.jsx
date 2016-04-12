import React from 'react';
import {Actions} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';

export default class ComposeButton extends React.Component {
  static displayName = 'ComposeButton';

  _onNewCompose = () => {
    Actions.composeNewBlankDraft()
  }

  render() {
    return (
      <button
        className="btn btn-toolbar item-compose"
        title="Compose new message"
        onClick={this._onNewCompose}>
        <RetinaImg name="toolbar-compose.png" mode={RetinaImg.Mode.ContentIsMask}/>
      </button>
    );
  }
}
