import _ from 'underscore';
import MailspringStore from 'mailspring-store';
import DatabaseStore from './database-store';
import Thread from '../models/thread';

class ThreadCountsStore extends MailspringStore {
  constructor() {
    super();
    this._counts = {};

    if (AppEnv.isMainWindow()) {
      // For now, unread counts are only retrieved in the main window.
      this._onCountsChangedDebounced = _.throttle(this._onCountsChanged, 1000);
      DatabaseStore.listen(change => {
        if (change.objectClass === Thread.name) {
          this._onCountsChangedDebounced();
        }
      });
      this._onCountsChangedDebounced();
    }
  }

  _onCountsChanged = () => {
    DatabaseStore._query('SELECT * FROM `ThreadCounts`').then(results => {
      const nextCounts = {};
      for (const { categoryId, unread, total } of results) {
        nextCounts[categoryId] = { unread, total };
      }
      if (_.isEqual(nextCounts, this._counts)) {
        return;
      }
      this._counts = nextCounts;
      this.trigger();
    });
  };

  unreadCountForCategoryId(catId) {
    if (this._counts[catId] === undefined) {
      return null;
    }
    return this._counts[catId]['unread'];
  }

  totalCountForCategoryId(catId) {
    if (this._counts[catId] === undefined) {
      return null;
    }
    return this._counts[catId]['total'];
  }
}

export default new ThreadCountsStore();
