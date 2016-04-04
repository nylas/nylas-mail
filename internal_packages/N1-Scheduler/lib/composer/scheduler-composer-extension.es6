import _ from 'underscore'
import React from 'react'
import {PLUGIN_ID} from '../scheduler-constants'
import ProposedTimeList from './proposed-time-list'
import {Actions, RegExpUtils, ComposerExtension} from 'nylas-exports'

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

  static _prepareEvent(inEvent, draft) {
    const event = inEvent
    if (!event.title || event.title.length === 0) {
      event.title = draft.subject;
    }

    event.participants = draft.participants().map((contact) => {
      return {
        name: contact.name,
        email: contact.email,
        status: "noreply",
      }
    })
    return event;
  }

  static _insertProposalsIntoBody(draft, metadata) {
    const nextDraft = draft;
    if (metadata && metadata.proposals) {
      const el = React.createElement(ProposedTimeList,
        {
          draft: nextDraft,
          inEmail: true,
          proposals: metadata.proposals,
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

    nextDraft = self._insertProposalsIntoBody(nextDraft, metadata)

    if (nextDraft.events.length > 0) {
      if (metadata.pendingEvent) {
        throw new Error(`Assertion Failure. Can't have both a pendingEvent \
and an event on a draft at the same time!`);
      }
      const event = self._prepareEvent(nextDraft.events[0].clone(), draft)
      nextDraft.events = [event]
    } else if (metadata && metadata.pendingEvent) {
      const event = self._prepareEvent(_.clone(metadata.pendingEvent), draft);
      metadata.pendingEvent = event;
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
