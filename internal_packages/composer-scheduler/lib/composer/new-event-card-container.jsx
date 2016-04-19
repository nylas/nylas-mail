import React, {Component, PropTypes} from 'react';
import SchedulerActions from '../scheduler-actions'
import NewEventCard from './new-event-card'
import {PLUGIN_ID} from '../scheduler-constants'
import {Utils, Event} from 'nylas-exports';

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
    draft: PropTypes.object.isRequired,
    session: PropTypes.object.isRequired,
  }

  constructor(props) {
    super(props);
  }

  componentDidMount() {
    this._unlisten = SchedulerActions.confirmChoices.listen(this._onConfirmChoices);
  }

  componentWillUnmount() {
    if (this._unlisten) {
      this._unlisten();
    }
  }

  _onConfirmChoices = ({proposals = [], draftClientId}) => {
    const {draft} = this.props;

    if (draft.clientId !== draftClientId) {
      return;
    }

    const metadata = draft.metadataForPluginId(PLUGIN_ID) || {};
    if (proposals.length === 0) {
      delete metadata.proposals;
    } else {
      metadata.proposals = proposals;
    }
    this.props.session.changes.addPluginMetadata(PLUGIN_ID, metadata);
  }

  _getEvent() {
    const metadata = this.props.draft.metadataForPluginId(PLUGIN_ID);
    if (metadata && metadata.pendingEvent) {
      return new Event().fromJSON(metadata.pendingEvent || {});
    }
    return null
  }

  _updateEvent = (newData) => {
    const {draft, session} = this.props;

    const newEvent = Object.assign(this._getEvent().clone(), newData);
    const newEventJSON = newEvent.toJSON();

    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    if (!Utils.isEqual(metadata.pendingEvent, newEventJSON)) {
      metadata.pendingEvent = newEventJSON;
      session.changes.addPluginMetadata(PLUGIN_ID, metadata);
    }
  }

  _removeEvent = () => {
    const {draft, session} = this.props;
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    if (metadata) {
      delete metadata.pendingEvent;
      delete metadata.proposals
      session.changes.addPluginMetadata(PLUGIN_ID, metadata);
    }
  }

  render() {
    const event = this._getEvent();
    let card = false;

    if (event) {
      card = (
        <NewEventCard event={event}
          ref="newEventCard"
          draft={this.props.draft}
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
