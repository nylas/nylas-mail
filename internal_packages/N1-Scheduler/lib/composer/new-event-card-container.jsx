import React, {Component, PropTypes} from 'react';
import NewEventCard from './new-event-card'
import {PLUGIN_ID} from '../scheduler-constants'
import {Utils, Event, Actions, DraftStore} from 'nylas-exports';
const MEETING_REQUEST = "MEETING_REQUEST"
const PENDING_EVENT = "PENDING_EVENT"

/**
 * When you're creating an event you can either be creating:
 *
 * 1. A Meeting Request with a specific start and end time
 * 2. OR a `pendingEvent` template that has a set of proposed times.
 *
 * The former (1) is represented by an `Event` object on the `draft.events`
 * field of a draft.
 *
 * The latter (2) is represented by a `pendingEvent` key on the metadata
 * of the `draft`.
 *
 * These are mutually exclusive and shouldn't exist at the same time on a
 * draft.
 */
export default class NewEventCardContainer extends Component {
  static displayName = 'NewEventCardContainer';

  static propTypes = {
    draftClientId: PropTypes.string,
    threadId: PropTypes.string,
  };

  constructor(props) {
    super(props);
    this.state = {event: null};
    this._session = null;
    this._mounted = false;
    this._usub = () => {}
  }

  componentDidMount() {
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

  _eventType(draft) {
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    const hasPendingEvent = metadata && metadata.pendingEvent
    if (draft.events && draft.events.length > 0) {
      if (hasPendingEvent) {
        throw new Error(`Assertion Failure. Can't have both a pendingEvent \
and an event on a draft at the same time!`);
      }
      return MEETING_REQUEST
    } else if (hasPendingEvent) {
      return PENDING_EVENT
    }
    return null
  }

  _onDraftChange = () => {
    const draft = this._session.draft();

    let event = null;
    const eventType = this._eventType(draft)

    if (eventType === MEETING_REQUEST) {
      event = draft.events[0]
    } else if (eventType === PENDING_EVENT) {
      event = this._getPendingEvent(draft.metadataForPluginId(PLUGIN_ID))
    }

    this.setState({event});
  }

  _getPendingEvent(metadata) {
    return new Event().fromJSON(metadata.pendingEvent || {})
  }

  _updateDraftEvent(newData) {
    const draft = this._session.draft();
    const data = newData
    const event = Object.assign(draft.events[0].clone(), data);
    if (!Utils.isEqual(event, draft.events[0])) {
      this._session.changes.add({events: [event]});  // triggers draft change
      this._session.changes.commit();
    }
  }

  _updatePendingEvent(newData) {
    const draft = this._session.draft()
    const metadata = draft.metadataForPluginId(PLUGIN_ID)
    const pendingEvent = Object.assign(this._getPendingEvent(metadata).clone(), newData)
    const pendingEventJSON = pendingEvent.toJSON()
    if (!Utils.isEqual(pendingEventJSON, metadata.pendingEvent)) {
      metadata.pendingEvent = pendingEventJSON;
      Actions.setMetadata(draft, PLUGIN_ID, metadata);
    }
  }

  _removeDraftEvent() {
    this._session.changes.add({events: []});
    return this._session.changes.commit();
  }

  _removePendingEvent() {
    const draft = this._session.draft()
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    delete metadata.pendingEvent
    Actions.setMetadata(draft, PLUGIN_ID, metadata);
  }

  _onEventChange = (newData) => {
    const eventType = this._eventType(this._session.draft());
    if (eventType === MEETING_REQUEST) {
      this._updateDraftEvent(newData)
    } else if (eventType === PENDING_EVENT) {
      this._updatePendingEvent(newData)
    }
  }

  _onEventRemove = () => {
    const eventType = this._eventType(this._session.draft());
    if (eventType === MEETING_REQUEST) {
      this._removeDraftEvent()
    } else if (eventType === PENDING_EVENT) {
      this._removePendingEvent()
    }
  }

  render() {
    let card = false;
    if (this._session && this.state.event) {
      card = (
        <NewEventCard event={this.state.event}
          draft={this._session.draft()}
          onRemove={this._onEventRemove}
          onChange={this._onEventChange}
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

