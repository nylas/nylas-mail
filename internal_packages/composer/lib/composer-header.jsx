import _ from 'underscore';
import React from 'react';
import ReactDOM from 'react-dom';
import AccountContactField from './account-contact-field';
import ParticipantsTextField from './participants-text-field';
import {Utils, Actions, AccountStore} from 'nylas-exports';
import {KeyCommandsRegion} from 'nylas-component-kit';

import CollapsedParticipants from './collapsed-participants';
import ComposerHeaderActions from './composer-header-actions';

import ConnectToFlux from './decorators/connect-to-flux';
import Fields from './fields';

const ScopedFromField = ConnectToFlux(AccountContactField, {
  stores: [AccountStore],
  getStateFromStores: (props) => {
    const savedOrReplyToThread = !!props.draft.threadId;
    if (savedOrReplyToThread) {
      return {accounts: [AccountStore.accountForId(props.draft.accountId)]};
    }
    return {accounts: AccountStore.accounts()}
  },
});

export default class ComposerHeader extends React.Component {
  static displayName = "ComposerHeader";

  static propTypes = {
    draft: React.PropTypes.object.isRequired,

    session: React.PropTypes.object.isRequired,
  }

  static contextTypes = {
    parentTabGroup: React.PropTypes.object,
  }

  constructor(props = {}) {
    super(props)
    this.state = this._initialStateForDraft(this.props.draft);
  }

  componentWillReceiveProps(nextProps) {
    if (this.props.session !== nextProps.session) {
      this.setState(this._initialStateForDraft(nextProps.draft));
    } else {
      this._ensureFilledFieldsEnabled(nextProps.draft);
    }
  }

  showAndFocusField = (fieldName) => {
    const enabledFields = _.uniq([].concat(this.state.enabledFields, [fieldName]));
    const participantsFocused = this.state.participantsFocused || Fields.ParticipantFields.includes(fieldName);

    Utils.waitFor(() => this.refs[fieldName]).then(() =>
      this.refs[fieldName].focus()
    ).catch(() => {
    })

    this.setState({enabledFields, participantsFocused});
  }

  hideField = (fieldName) => {
    if (ReactDOM.findDOMNode(this.refs[fieldName]).contains(document.activeElement)) {
      this.context.parentTabGroup.shiftFocus(-1)
    }

    const enabledFields = _.without(this.state.enabledFields, fieldName)
    this.setState({enabledFields})
  }

  _ensureFilledFieldsEnabled(draft) {
    let enabledFields = this.state.enabledFields;
    if (!_.isEmpty(draft.cc)) {
      enabledFields = enabledFields.concat([Fields.Cc]);
    }
    if (!_.isEmpty(draft.bcc)) {
      enabledFields = enabledFields.concat([Fields.Bcc]);
    }
    if (enabledFields !== this.state.enabledFields) {
      this.setState({enabledFields});
    }
  }

  _initialStateForDraft(draft) {
    const enabledFields = [Fields.To];
    if (!_.isEmpty(draft.cc)) {
      enabledFields.push(Fields.Cc);
    }
    if (!_.isEmpty(draft.bcc)) {
      enabledFields.push(Fields.Bcc);
    }
    enabledFields.push(Fields.From);
    if (this._shouldEnableSubject()) {
      enabledFields.push(Fields.Subject);
    }

    return {
      enabledFields: enabledFields,
      participantsFocused: false,
    };
  }

  _shouldEnableSubject = () => {
    if (_.isEmpty(this.props.draft.subject)) {
      return true;
    }
    if (Utils.isForwardedMessage(this.props.draft)) {
      return true;
    }
    if (this.props.draft.replyToMessageId) {
      return false;
    }
    return true;
  }

  _onChangeParticipants = (changes) => {
    this.props.session.changes.add(changes);
    Actions.draftParticipantsChanged(this.props.draft.clientId, changes);
  }

  _onChangeSubject = (event) => {
    this.props.session.changes.add({subject: event.target.value});
  }

  _onFocusInParticipants = () => {
    const fieldName = this.state.participantsLastActiveField || Fields.To;
    Utils.waitFor(() =>
      this.refs[fieldName]
    ).then(() =>
      this.refs[fieldName].focus()
    ).catch(() => {
    });

    this.setState({
      participantsFocused: true,
      participantsLastActiveField: null,
    });
  }

  _onFocusOutParticipants = (lastFocusedEl) => {
    const active = Fields.ParticipantFields.find((fieldName) =>
      this.refs[fieldName] ? ReactDOM.findDOMNode(this.refs[fieldName]).contains(lastFocusedEl) : false
    );
    this.setState({
      participantsFocused: false,
      participantsLastActiveField: active,
    });
  }

  _renderParticipants = () => {
    let content = null;
    if (this.state.participantsFocused) {
      content = this._renderFields();
    } else {
      content = (
        <CollapsedParticipants
          to={this.props.draft.to}
          cc={this.props.draft.cc}
          bcc={this.props.draft.bcc}
        />
      )
    }

    // When the participants field collapses, we store the field that was last
    // focused onto our state, so that we can restore focus to it when the fields
    // are expanded again.
    return (
      <KeyCommandsRegion
        tabIndex={-1}
        ref="participantsContainer"
        className="expanded-participants"
        onFocusIn={this._onFocusInParticipants}
        onFocusOut={this._onFocusOutParticipants}>
        {content}
      </KeyCommandsRegion>
    );
  }

  _renderSubject = () => {
    if (!this.state.enabledFields.includes(Fields.Subject)) {
      return false;
    }
    return (
      <div
        key="subject-wrap"
        className="compose-subject-wrap">
        <input
          type="text"
          name="subject"
          ref={Fields.Subject}
          placeholder="Subject"
          value={this.props.draft.subject}
          onChange={this._onChangeSubject}/>
      </div>
    );
  }

  _renderFields = () => {
    const {to, cc, bcc, from} = this.props.draft;

    // Note: We need to physically add and remove these elements, not just hide them.
    // If they're hidden, shift-tab between fields breaks.
    const fields = [];

    fields.push(
      <ParticipantsTextField
        ref={Fields.To}
        key="to"
        field="to"
        change={this._onChangeParticipants}
        className="composer-participant-field to-field"
        participants={{to, cc, bcc}} />
    )

    if (this.state.enabledFields.includes(Fields.Cc)) {
      fields.push(
        <ParticipantsTextField
          ref={Fields.Cc}
          key="cc"
          field="cc"
          change={this._onChangeParticipants}
          onEmptied={ () => this.hideField(Fields.Cc) }
          className="composer-participant-field cc-field"
          participants={{to, cc, bcc}} />
      )
    }

    if (this.state.enabledFields.includes(Fields.Bcc)) {
      fields.push(
        <ParticipantsTextField
          ref={Fields.Bcc}
          key="bcc"
          field="bcc"
          change={this._onChangeParticipants}
          onEmptied={ () => this.hideField(Fields.Bcc) }
          className="composer-participant-field bcc-field"
          participants={{to, cc, bcc}} />
      )
    }

    if (this.state.enabledFields.includes(Fields.From)) {
      fields.push(
        <ScopedFromField
          key="from"
          ref={Fields.From}
          draft={this.props.draft}
          onChange={this._onChangeParticipants}
          value={from[0]}
        />
      )
    }

    return fields;
  }

  render() {
    return (
      <div className="composer-header">
        <ComposerHeaderActions
          draftClientId={this.props.draft.clientId}
          enabledFields={this.state.enabledFields}
          participantsFocused={this.state.participantsFocused}
          onShowAndFocusField={this.showAndFocusField}
        />
        {this._renderParticipants()}
        {this._renderSubject()}
      </div>
    )
  }
}
