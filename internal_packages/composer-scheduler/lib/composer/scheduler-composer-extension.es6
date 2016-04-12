import React from 'react'
import {PLUGIN_ID} from '../scheduler-constants'
import NewEventPreview from './new-event-preview'
import ProposedTimeList from './proposed-time-list'
import {Event, Actions, RegExpUtils, ComposerExtension} from 'nylas-exports'

/**
 * Inserts the set of Proposed Times into the body of the HTML email.
 *
 */
export default class SchedulerComposerExtension extends ComposerExtension {

  static listRegex() {
    return new RegExp(/<proposed-time-list>.*<\/proposed-time-list>/)
  }

  static _findInsertionPoint(body) {
    const checks = [
      /<!-- <signature> -->/,
      RegExpUtils.signatureRegex(),
      RegExpUtils.n1QuoteStartRegex(),
    ]

    let insertionPoint = -1
    for (const check of checks) {
      insertionPoint = body.search(check);
      if (insertionPoint >= 0) { break; }
    }
    if (insertionPoint === -1) { insertionPoint = body.length }
    return insertionPoint
  }

  static _insertInBody(body, markup) {
    // Remove any existing signature in the body
    const re = SchedulerComposerExtension.listRegex()
    const cleanBody = body.replace(re, "");

    const insertionPoint = SchedulerComposerExtension._findInsertionPoint(cleanBody)

    const contentBefore = cleanBody.slice(0, insertionPoint);
    const contentAfter = cleanBody.slice(insertionPoint);
    const wrapS = "<proposed-time-list>"
    const wrapE = "</proposed-time-list>"

    return contentBefore + wrapS + markup + wrapE + contentAfter
  }

  static _prepareEvent(inEvent, draft, metadata) {
    const event = inEvent
    if (!event.title) {
      event.title = "";
    }

    event.participants = draft.participants().map((contact) => {
      return {
        name: contact.name,
        email: contact.email,
        status: "noreply",
      }
    })

    if (metadata.proposals) {
      event.end = null
      event.start = null
    }
    return event;
  }

  // We must set the `preparedEvent` to be exactly what could be posted to
  // the /events endpoint of the API.
  static _cleanEventJSON(rawJSON) {
    const json = rawJSON;
    delete json.client_id;
    delete json.id;
    json.when = {
      start_time: json._start,
      end_time: json._end,
    }
    delete json._start
    delete json._end
    return json
  }

  static _insertProposalsIntoBody(draft, metadata) {
    const nextDraft = draft;
    if (metadata.proposals && metadata.proposals.length > 0) {
      const el = React.createElement(ProposedTimeList,
        {
          draft: nextDraft,
          event: metadata.pendingEvent,
          inEmail: true,
          proposals: metadata.proposals,
        });
      const markup = React.renderToStaticMarkup(el);
      const nextBody = SchedulerComposerExtension._insertInBody(nextDraft.body, markup)
      nextDraft.body = nextBody;
    } else {
      const el = React.createElement(NewEventPreview,
        {
          event: metadata.pendingEvent,
        });
      const markup = React.renderToStaticMarkup(el);
      const nextBody = SchedulerComposerExtension._insertInBody(nextDraft.body, markup)
      nextDraft.body = nextBody;
    }
    return nextDraft
  }

  static applyTransformsToDraft({draft}) {
    const self = SchedulerComposerExtension
    let nextDraft = draft.clone();
    const metadata = draft.metadataForPluginId(PLUGIN_ID)
    if (metadata && metadata.pendingEvent) {
      nextDraft = self._insertProposalsIntoBody(nextDraft, metadata);
      const nextEvent = new Event().fromJSON(metadata.pendingEvent);
      const nextEventPrepared = self._prepareEvent(nextEvent, draft, metadata);
      metadata.pendingEvent = self._cleanEventJSON(nextEventPrepared.toJSON());
      Actions.setMetadata(nextDraft, PLUGIN_ID, metadata);
    }

    return nextDraft;
  }

  static unapplyTransformsToDraft({draft}) {
    const nextDraft = draft.clone();
    const re = SchedulerComposerExtension.listRegex()
    const body = nextDraft.body.replace(re, "");
    nextDraft.body = body;
    return nextDraft
  }
}
