import NylasStore from 'nylas-store';

import {
  Rx,
  Thread,
  Actions,
  Matcher,
  WorkspaceStore,
  FocusedContentStore,
  FocusedPerspectiveStore,
  RecentlyReadStore } from 'nylas-exports';

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

      const notInSet = model => {
        // The "Unread" view shows all threads which are unread. When you read a thread,
        // it doesn't disappear until you leave the view and come back. This behavior
        // is implemented by keeping track of messages being read and manually
        // whitelisting them in the query.

        let inSetMatchers;
        if (RecentlyReadStore.ids.length > 0) {
          const recentlyReadMatcher = Thread.attributes.id.in(RecentlyReadStore.ids);
          inSetMatchers = new Matcher.Or([
            new Matcher.And(matchers),
            recentlyReadMatcher,
          ]);
        } else {
          inSetMatchers = matchers;
        }

        if (inSetMatchers) {
          return model.matches(inSetMatchers) === false;
        }
        return next.offsetOfId(model.id) === -1;
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
