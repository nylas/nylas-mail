import MailspringStore from 'mailspring-store';
import AccountStore from './account-store';
import WorkspaceStore from './workspace-store';
import DatabaseStore from './database-store';
import Actions from '../actions';
import Model from '../models/model';

/**
Public: The FocusedContentStore provides access to the objects currently selected
or otherwise focused in the window. Normally, focus would be maintained internally
by components that show models. The FocusedContentStore makes the concept of
selection public so that you can observe focus changes and trigger your own changes
to focus.

Since {FocusedContentStore} is a Flux-compatible Store, you do not call setters
on it directly. Instead, use {Actions::setFocus} or
{Actions::setCursorPosition} to set focus. The FocusedContentStore observes
these models, changes it's state, and broadcasts to it's observers.

Note: The {FocusedContentStore} triggers when a focused model is changed, even if
it's ID has not. For example, if the user has a {Thread} selected and removes a tag,
{FocusedContentStore} will trigger so you can fetch the new version of the
{Thread}. If you observe the {FocusedContentStore} properly, you should always
have the latest version of the the selected object.

**Standard Collections**:

   - thread
   - file

**Example: Observing the Selected Thread**

```js
this.unsubscribe = FocusedContentStore.listen(this._onFocusChanged, this)

...

// Called when focus has changed, or when the focused model has been modified.
_onFocusChanged: =>
  thread = FocusedContentStore.focused('thread')
  if thread
    console.log(`${thread.subject} is selected!`)
  else
    console.log("No thread is selected!")
```

Section: Stores
*/
class FocusedContentStore extends MailspringStore {
  constructor() {
    super();
    this._resetInstanceVars();
    this.listenTo(AccountStore, this._onAccountsChange);
    this.listenTo(WorkspaceStore, this._onWorkspaceChange);
    this.listenTo(DatabaseStore, this._onDataChange);
    this.listenTo(Actions.setFocus, this._onFocus);
    this.listenTo(Actions.setCursorPosition, this._onFocusKeyboard);
  }

  triggerAfterAnimationFrame(payload) {
    window.requestAnimationFrame(() => this.trigger(payload));
  }

  _resetInstanceVars() {
    this._focused = {};
    this._focusedUsingClick = {};
    this._keyboardCursor = {};
    this._keyboardCursorEnabled = WorkspaceStore.layoutMode() === 'list';
  }

  // Inbound Events

  _onAccountsChange = () => {
    // Ensure internal consistency by removing any focused items that belong
    // to accounts which no longer exist.
    const changed = [];

    for (const dict of [this._focused, this._keyboardCursor]) {
      for (const [collection, item] of Object.entries(dict)) {
        if (item && item.accountId && !AccountStore.accountForId(item.accountId)) {
          delete dict[collection];
          changed.push(collection);
        }
      }
    }

    if (changed.length > 0) {
      this.trigger({ impactsCollection: c => changed.includes(c) });
    }
  };

  _onFocusKeyboard = ({ collection, item }) => {
    if (item && !(item instanceof Model)) {
      throw new Error('focusKeyboard() requires a Model or null');
    }
    if (!collection) {
      throw new Error('focusKeyboard() requires a collection');
    }
    if (
      this._keyboardCursor[collection] &&
      item &&
      this._keyboardCursor[collection].id === item.id
    ) {
      return;
    }

    this._keyboardCursor[collection] = item;
    this.triggerAfterAnimationFrame({ impactsCollection: c => c === collection });
  };

  _onFocus = ({ collection, item, usingClick }) => {
    if (item && !(item instanceof Model)) {
      throw new Error('focus() requires a Model or null');
    }
    if (!collection) {
      throw new Error('focus() requires a collection');
    }

    // same item
    if (item && this._focused[collection] && this._focused[collection].id === item.id) {
      return;
    }

    // same nothing
    if (!item && !this._focused[collection]) {
      return;
    }

    this._focused[collection] = item;
    this._focusedUsingClick[collection] = usingClick;
    if (item) {
      this._keyboardCursor[collection] = item;
    }
    this.triggerAfterAnimationFrame({ impactsCollection: c => c === collection });
  };

  _onWorkspaceChange = () => {
    const keyboardCursorEnabled = WorkspaceStore.layoutMode() === 'list';

    if (keyboardCursorEnabled !== this._keyboardCursorEnabled) {
      this._keyboardCursorEnabled = keyboardCursorEnabled;

      if (keyboardCursorEnabled) {
        for (const [collection, item] of Object.entries(this._focused)) {
          this._keyboardCursor[collection] = item;
        }
        this._focused = {};
      } else {
        for (const [collection, item] of Object.entries(this._keyboardCursor)) {
          this._onFocus({ collection, item });
        }
      }
    }
    this.trigger({ impactsCollection: () => true });
  };

  _onDataChange = change => {
    // If one of the objects we're storing in our focused or keyboard cursor
    // dictionaries has changed, we need to let our observers know, since they
    // may now be holding on to outdated data.
    if (!change || !change.objectClass) {
      return;
    }

    const touched = [];

    for (const data of [this._focused, this._keyboardCursor]) {
      for (const [key, val] of Object.entries(data)) {
        if (!val || val.constructor.name !== change.objectClass) {
          continue;
        }
        for (const obj of change.objects) {
          if (val.id === obj.id) {
            data[key] = change.type === 'unpersist' ? null : obj;
            touched.push(key);
          }
        }
      }
    }

    if (touched.length > 0) {
      this.trigger({ impactsCollection: c => c in touched });
    }
  };

  // Public Methods

  /**
  Public: Returns the focused {Model} in the collection specified,
  or undefined if no item is focused.

  - `collection` The {String} name of a collection. Standard collections are
    listed above.
  */
  focused(collection) {
    return this._focused[collection];
  }

  /**
  Public: Returns the ID of the focused {Model} in the collection specified,
  or undefined if no item is focused.

  - `collection` The {String} name of a collection. Standard collections are
    listed above.
  */
  focusedId(collection) {
    return this._focused[collection] && this._focused[collection].id;
  }

  /**
  Public: Returns true if the item for the collection was focused via a click or
  false otherwise.

  - `collection` The {String} name of a collection. Standard collections are
    listed above.
  */
  didFocusUsingClick(collection) {
    return this._focusedUsingClick[collection] || false;
  }

  /**
  Public: Returns the {Model} the keyboard is currently focused on
  in the collection specified. Keyboard focus is not always separate from
  primary focus (selection). You can use {::keyboardCursorEnabled} to determine
  whether keyboard focus is enabled.

  - `collection` The {String} name of a collection. Standard collections are
    listed above.
  */
  keyboardCursor(collection) {
    return this._keyboardCursor[collection];
  }

  /**
  Public: Returns the ID of the {Model} the keyboard is currently focused on
  in the collection specified. Keyboard focus is not always separate from
  primary focus (selection). You can use {::keyboardCursorEnabled} to determine
  whether keyboard focus is enabled.

  - `collection` The {String} name of a collection. Standard collections are
    listed above.
  */
  keyboardCursorId(collection) {
    return this._keyboardCursor[collection] && this._keyboardCursor[collection].id;
  }

  /**
  Public: Returns a {Boolean} - `true` if the keyboard cursor concept applies in
  the current {WorkspaceStore} layout mode. The keyboard cursor is currently only
  enabled in `list` mode.
  */
  keyboardCursorEnabled() {
    return this._keyboardCursorEnabled;
  }
}

export default new FocusedContentStore();
