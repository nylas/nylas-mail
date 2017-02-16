import React, {Component, PropTypes} from 'react';
import {Utils, Event} from 'nylas-exports';

import SchedulerActions from '../scheduler-actions'
import NewEventCard from './new-event-card'
import NewEventPreview from './new-event-preview'
import {PLUGIN_ID} from '../scheduler-constants'
import NewEventHelper from './new-event-helper'
import RemoveEventHelper from './remove-event-helper'

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
 *
 * This component is an OverlayedComponent.
 *
 * The SchedulerComposerExtension::_insertNewEventCard will call
 * `EditorAPI::insert`. We pass `insert` a React element. Under the hood,
 * the `<OverlaidComponent>` wrapper will actually place an "anchor" tag
 * and absolutely position our element over that anchor tag.
 *
 * This component is also decorated with the `InflatesDraftClientId`
 * decorator. The former is necessary for OverlaidComponents to work. The
 * latter provides us with up-to-date `draft` and `session` props by
 * inflating a `draftClientId`.
 *
 * If the Anchor is deleted, or cut, then the `<OverlaidComponents />`
 * element will unmount the `NewEventCardContainer`.
 *
 * If the anchor re-appears (via paste or some other mechanism), then this
 * component will be re-mounted.
 *
 * We use the mounting and unmounting of this component as signals to add or
 * remove the metadata on the draft.
 */
export default class NewEventCardContainer extends Component {
  static displayName = 'NewEventCardContainer';

  static propTypes = {
    draft: PropTypes.object.isRequired,
    session: PropTypes.object.isRequired,
    style: PropTypes.object,
    isPreview: PropTypes.bool,
  }

  componentDidMount() {
    this._unlisten = SchedulerActions.confirmChoices.listen(::this._onConfirmChoices);
    NewEventHelper.restoreOrCreateEvent(this.props.session)
  }

  componentWillUnmount() {
    if (this._unlisten) {
      this._unlisten();
    }
    RemoveEventHelper.hideEventData(this.props.session)
  }

  _onConfirmChoices({proposals = [], draftClientId}) {
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
    // This will delete the metadata, but it won't remove the anchor from
    // the contenteditable. We also need to remove the event card.
    RemoveEventHelper.deleteEventData(this.props.session);
    SchedulerActions.removeEventCard();
  }

  render() {
    const {style, isPreview} = this.props;
    const event = this._getEvent();
    let card = false;

    if (isPreview) {
      return <NewEventPreview draft={this.props.draft} />
    }

    if (event) {
      card = (
        <NewEventCard
          event={event}
          ref="newEventCard"
          draft={this.props.draft}
          onRemove={this._removeEvent}
          onChange={this._updateEvent}
          onParticipantsClick={() => {}}
        />
      )
    }
    return (
      <div className="new-event-card-container" style={style}>
        {card}
      </div>
    )
  }
}
