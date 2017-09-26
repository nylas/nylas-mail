import _ from 'underscore';

import Model from '../flux/models/model';
import DatabaseStore from '../flux/stores/database-store';

export default class ListSelection {
  constructor(_view, callback) {
    this._view = _view;
    if (!this._view) {
      throw new Error('new ListSelection(): You must provide a view.');
    }
    this._unlisten = DatabaseStore.listen(this._applyChangeRecord, this);
    this._caches = {};
    this._items = [];

    this.trigger = () => {
      this._caches = {};
      callback();
    };
  }

  cleanup() {
    this._unlisten();
  }

  count() {
    return this._items.length;
  }

  ids() {
    // ListTabular asks for ids /a lot/. Cache this value and clear it on trigger.
    if (this._caches.ids == null) {
      this._caches.ids = this._items.map(i => i.id);
    }
    return this._caches.ids;
  }

  items() {
    return _.clone(this._items);
  }

  top() {
    return this._items[this._items.length - 1];
  }

  clear() {
    this.set([]);
  }

  set(items) {
    this._items = [];
    for (const item of items) {
      if (!(item instanceof Model)) {
        throw new Error('set must be called with Models');
      }
      this._items.push(item);
    }
    this.trigger(this);
  }

  toggle(item) {
    if (!item) {
      return;
    }
    if (!(item instanceof Model)) {
      throw new Error('toggle must be called with a Model');
    }

    const without = _.reject(this._items, t => t.id === item.id);
    if (without.length < this._items.length) {
      this._items = without;
    } else {
      this._items.push(item);
    }
    this.trigger(this);
  }

  add(item) {
    if (!item) {
      return;
    }
    if (!(item instanceof Model)) {
      throw new Error('add must be called with a Model');
    }

    const updated = this._items.filter(t => t.id !== item.id);
    updated.push(item);

    if (updated.length !== this._items.length) {
      this._items = updated;
      this.trigger(this);
    }
  }

  remove(itemOrItems) {
    if (!itemOrItems) {
      return;
    }

    let items = itemOrItems;
    if (!(items instanceof Array)) {
      items = [items];
    }

    for (const item of items) {
      if (!(item instanceof Model)) {
        throw new Error('remove: Must be passed a model or array of models');
      }
    }

    const itemIds = items.map(i => i.id);
    const nextItems = this._items.filter(t => !itemIds.includes(t.id));
    if (nextItems.length < this._items.length) {
      this._items = nextItems;
      this.trigger(this);
    }
  }

  removeItemsNotMatching(matchers) {
    const count = this._items.length;
    this._items = this._items.filter(t => t.matches(matchers));
    if (this._items.length !== count) {
      this.trigger(this);
    }
  }

  expandTo(item) {
    if (!item) {
      return;
    }
    if (!(item instanceof Model)) {
      throw new Error('expandTo must be called with a Model');
    }

    if (this._items.length === 0) {
      this._items.push(item);
    } else {
      // When expanding selection, you expand from the last selected item
      // to the item the user clicked on. If the item is already selected,
      // remove it from the selected array and reselect it so that the
      // items are in the _items array in the order they were selected.
      // (important for walking)
      const relativeTo = this._items[this._items.length - 1];
      const startIdx = this._view.indexOfId(relativeTo.id);
      const endIdx = this._view.indexOfId(item.id);
      if (startIdx === -1 || endIdx === -1) {
        return;
      }
      const count = Math.abs(startIdx - endIdx) + 1;
      const indexes = new Array(count)
        .fill(0)
        .map((val, idx) => (startIdx > endIdx ? startIdx - idx : startIdx + idx));
      indexes.forEach(idx => {
        const idxItem = this._view.get(idx);
        this._items = _.reject(this._items, t => t.id === idxItem.id);
        this._items.push(idxItem);
      });
    }
    this.trigger();
  }

  walk({ current, next }) {
    // When the user holds shift and uses the arrow keys to modify their selection,
    // we call that "walking". When walking you're usually selecting items. However,
    // if you're walking "back" through your selection in the same order you selected
    // them, you're undoing selections you've made. The order of the _items array
    // is actually important - you can only deselect FROM the head back down the
    // selection history.

    const ids = this.ids();
    const noSelection = this._items.length === 0;
    const neitherSelected =
      (!current || ids.indexOf(current.id) === -1) && (!next || ids.indexOf(next.id) === -1);

    if (noSelection || neitherSelected) {
      if (current) {
        this._items.push(current);
      }
      if (next) {
        this._items.push(next);
      }
    } else {
      let selectionPostPopHeadId = null;
      if (this._items.length > 1) {
        selectionPostPopHeadId = this._items[this._items.length - 2].id;
      }

      if (next.id === selectionPostPopHeadId) {
        this._items.pop();
      } else {
        // Important: As you walk over this item, remove it and re-push it on the selected
        // array even if it's already there. That way, the items in _items are always
        // in the order you walked over them, and you can walk back to deselect them.
        this._items = _.reject(this._items, t => t.id === next.id);
        this._items.push(next);
      }
    }

    return this.trigger();
  }

  _applyChangeRecord(change) {
    if (this._items.length === 0) {
      return;
    }
    if (change.objectClass !== this._items[0].constructor.name) {
      return;
    }

    if (change.type === 'unpersist') {
      this.remove(change.objects);
    } else if (change.type === 'persist') {
      let touched = 0;
      for (const newer of change.objects) {
        for (let idx = 0; idx < this._items.length; idx++) {
          const existing = this._items[idx];
          if (existing.id === newer.id) {
            this._items[idx] = newer;
            touched += 1;
            break;
          }
        }
      }
      if (touched > 0) {
        this.trigger(this);
      }
    }
  }
}
