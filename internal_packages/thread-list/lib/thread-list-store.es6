import _ from 'underscore';
import NylasStore from 'nylas-store';

import {
  Rx,
  Thread,
  Message,
  Actions,
  DatabaseStore,
  WorkspaceStore,
  FocusedContentStore,
  TaskQueueStatusStore,
  FocusedPerspectiveStore } from 'nylas-exports';

import { ListTabular } from 'nylas-component-kit';

import ThreadListDataSource from './thread-list-data-source';

class ThreadListStore extends NylasStore {
  constructor(props) {
    super(props)
    this.dataSource = this.dataSource.bind(this);
    this._onPerspectiveChanged = this._onPerspectiveChanged.bind(this);
    this.listenTo(FocusedPerspectiveStore, this._onPerspectiveChanged);
    this.createListDataSource();
  }

  dataSource() {
    return this._dataSource;
  }

  createListDataSource() {
    if (typeof this._dataSourceUnlisten === 'function') {
      this._dataSourceUnlisten();
    }
    this._dataSource = null;

    const threadsSubscription = FocusedPerspectiveStore.current().threads();
    if (threadsSubscription) {
      this._dataSource = new ThreadListDataSource(threadsSubscription);
      this._dataSourceUnlisten = this._dataSource.listen(this._onDataChanged, this);

    } else {
      this._dataSource = new ListTabular.DataSource.Empty();
    }

    this.trigger(this);
    return Actions.setFocus({collection: 'thread', item: null});
  }

  selectionObservable() {
    return Rx.Observable.fromListSelection(this);
  }

  // Inbound Events

  _onPerspectiveChanged() {
    return this.createListDataSource();
  }

  _onDataChanged({previous, next} = {}) {
    // This code keeps the focus and keyboard cursor in sync with the thread list.
    // When the thread list changes, it looks to see if the focused thread is gone,
    // or no longer matches the query criteria and advances the focus to the next
    // thread.

    // This means that removing a thread from view in any way causes selection
    // to advance to the adjacent thread. Nice and declarative.

    if (previous && next) {
      const focused = FocusedContentStore.focused('thread');
      const keyboard = FocusedContentStore.keyboardCursor('thread');
      const viewModeAutofocuses = WorkspaceStore.layoutMode() === 'split' || WorkspaceStore.topSheet().root === true;
      const nextQuery = next.query();
      const matchers = nextQuery ? nextQuery.matchers() : false;

      const focusedIndex = focused ? previous.offsetOfId(focused.id) : -1;
      const keyboardIndex = keyboard ? previous.offsetOfId(keyboard.id) : -1;

      const nextItemFromIndex = i => {
        let nextIndex;
        const nextModel = next.modelAtOffset(i - 1);
        if (i > 0 && (nextModel ? nextModel.unread : i >= next.count())) {
          nextIndex = i - 1;
        } else {
          nextIndex = i;
        }

        // May return null if no thread is loaded at the next index
        return next.modelAtOffset(nextIndex);
      };

        if (matchers) {
          return model.matches(matchers) === false;
      const notInSet = model => {
        } else {
          return next.offsetOfId(model.id) === -1;
        }
      };

      if (viewModeAutofocuses && focused && notInSet(focused)) {
        Actions.setFocus({collection: 'thread', item: nextItemFromIndex(focusedIndex)});
      }

      if (keyboard && notInSet(keyboard)) {
        Actions.setCursorPosition({collection: 'thread', item: nextItemFromIndex(keyboardIndex)});
      }
    }
  }
}

export default new ThreadListStore();
