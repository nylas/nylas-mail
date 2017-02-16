import _ from 'underscore'
import React from 'react'
import {Rx, Thread, DatabaseStore} from 'nylas-exports'
import SalesforceIcon from '../shared-components/salesforce-icon'
import SalesforceObject from '../models/salesforce-object'
import {relatedSObjectsForThread} from '../related-object-helpers'

function SearchBarResult(sObject) {
  return (
    <span className="salesforce-search-bar-result">
      <SalesforceIcon objectType={sObject.type} />
      <span>{sObject.name}</span>
    </span>
  )
}

function _searchObjects(name) {
  return DatabaseStore.findAll(SalesforceObject).search(name)
}

let idleCallback = -1;

function _forAllPages(fn, offset = 0) {
  const SERACH_SIZE = 100;
  return DatabaseStore.findAll(Thread)
  .limit(SERACH_SIZE)
  .offset(offset)
  .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
  .then((threads) => {
    if (!fn(threads)) return;
    window.cancelIdleCallback(idleCallback)
    idleCallback = window.requestIdleCallback(() => {
      _forAllPages(fn, offset + SERACH_SIZE);
    })
  })
}

export default class SalesforceSearchBarResults extends React.Component {
  static displayName = "SalesforceSearchBarResults";

  static searchLabel() { return "Salesforce Objects" }

  static fetchSearchSuggestions(searchQuery) {
    return Promise.map(_searchObjects(searchQuery), (sObject) => {
      return {
        customElement: SearchBarResult(sObject),
        label: sObject.id,
        value: sObject.name,
      }
    })
  }

  static observeThreadIdsForQuery(searchQuery) {
    let cancelPagination = false;
    return Rx.Observable.create((observer) => {
      _searchObjects(searchQuery)
      .then((sObjects => {
        if (sObjects.length === 0) {
          observer.onCompleted();
          return;
        }
        const ids = new Set(sObjects.map(o => o.id))
        _forAllPages((threads) => {
          if (cancelPagination) return false;
          if (threads.length === 0) return false;
          const threadIds = threads.filter((thread) => {
            return _.any(relatedSObjectsForThread(thread),
              (sObject) => ids.has(sObject.id))
          }).map(t => t.id);
          observer.onNext(threadIds);
          return true;
        })
      }))
      return Rx.Disposable.create(() => {
        window.cancelIdleCallback(idleCallback)
        cancelPagination = true;
      })
    })
  }
}
