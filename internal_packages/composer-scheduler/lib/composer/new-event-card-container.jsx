import React, {Component, PropTypes} from 'react';
import NewEventCard from './new-event-card'
import {PLUGIN_ID} from '../scheduler-constants'
import {Utils, Event, Actions, DraftStore} from 'nylas-exports';

/**
 * When you're creating an event you can either be creating:
 *
 * 1. A Meeting Request with a specific start and end time
 * 2. OR a `pendingEvent` template that has a set of proposed times.
 *
 * Both are represented by a `pendingEvent` object on the `metadata` that
 * holds the JSONified representation of the `Event`
 *
 * #2 adds a set of `proposals` on the metadata object.
 */
export default class NewEventCardContainer extends Component {
  static displayName = 'NewEventCardContainer';

  static propTypes = {
    draftClientId: PropTypes.string,
  }

  constructor(props) {
    super(props);
    this.state = {event: null};
    this._session = null;
    this._mounted = false;
    this._usub = () => {}
  }

  componentWillMount() {
    this._mounted = true;
    this._loadDraft(this.props.draftClientId);
  }

  componentWillReceiveProps(newProps) {
    this._loadDraft(newProps.draftClientId);
  }

  componentWillUnmount() {
    this._mounted = false;
    this._usub()
  }

  _loadDraft(draftClientId) {
    DraftStore.sessionForClientId(draftClientId).then(session => {
      // Only run if things are still relevant: component is mounted
      // and draftClientIds still match
      if (this._mounted) {
        this._session = session;
        this._usub()
        this._usub = session.listen(this._onDraftChange);
        this._onDraftChange();
      }
    });
  }

  _onDraftChange = () => {
    this.setState({event: this._getEvent()});
  }

  _getEvent() {
    const metadata = this._session.draft().metadataForPluginId(PLUGIN_ID);
    if (metadata && metadata.pendingEvent) {
      return new Event().fromJSON(metadata.pendingEvent || {})
    }
    return null
  }

  _updateEvent = (newData) => {
    const newEvent = Object.assign(this._getEvent().clone(), newData)
    const newEventJSON = newEvent.toJSON();

    const metadata = this._session.draft().metadataForPluginId(PLUGIN_ID);
    if (!Utils.isEqual(metadata.pendingEvent, newEventJSON)) {
      metadata.pendingEvent = newEventJSON;
      this._session.changes.addPluginMetadata(PLUGIN_ID, metadata);
    }
  }

  _removeEvent = () => {
    const draft = this._session.draft()
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    if (metadata) {
      delete metadata.pendingEvent
      delete metadata.proposals
      Actions.setMetadata(draft, PLUGIN_ID, metadata);
    }
  }

  render() {
    let card = false;
    if (this._session && this.state.event) {
      card = (
        <NewEventCard event={this.state.event}
          draft={this._session.draft()}
          onRemove={this._removeEvent}
          onChange={this._updateEvent}
          onParticipantsClick={() => {}}
        />
      )
    }
    return (
      <div className="new-event-card-container">
        {card}
      </div>
    )
  }
}
