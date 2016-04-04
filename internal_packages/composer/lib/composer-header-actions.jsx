import React from 'react';
import Fields from './fields';
import {Actions} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';

export default class ComposerHeaderActions extends React.Component {
  static displayName = 'ComposerHeaderActions';

  static propTypes = {
    draftClientId: React.PropTypes.string.isRequired,
    enabledFields: React.PropTypes.array.isRequired,
    participantsFocused: React.PropTypes.bool,
    onShowAndFocusField: React.PropTypes.func.isRequired,
  }

  _onPopoutComposer = () => {
    Actions.composePopoutDraft(this.props.draftClientId);
  }

  render() {
    const items = [];

    if (this.props.participantsFocused) {
      if (!this.props.enabledFields.includes(Fields.Cc)) {
        items.push(
          <span className="action show-cc" key="cc"
                onClick={ () => this.props.onShowAndFocusField(Fields.Cc) }>Cc</span>
        );
      }

      if (!this.props.enabledFields.includes(Fields.Bcc)) {
        items.push(
          <span className="action show-bcc" key="bcc"
                onClick={ () => this.props.onShowAndFocusField(Fields.Bcc) }>Bcc</span>
        );
      }
    }

    if (!this.props.enabledFields.includes(Fields.Subject)) {
      items.push(
        <span className="action show-subject" key="subject"
              onClick={ () => this.props.onShowAndFocusField(Fields.Subject) }>Subject</span>
      );
    }

    if (!NylasEnv.isComposerWindow()) {
      items.push(
        <span
          className="action show-popout"
          key="popout"
          title="Popout composer…"
          style={{paddingLeft: "1.5em"}}
          onClick={this._onPopoutComposer}>
          <RetinaImg
            name="composer-popout.png"
            mode={RetinaImg.Mode.ContentIsMask}
            style={{position: "relative", top: "-2px"}}
          />
        </span>
      );
    }

    return (
      <div className="composer-header-actions">
        {items}
      </div>
    );
  }
}
