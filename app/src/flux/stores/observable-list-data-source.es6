import { ListTabular } from 'mailspring-component-kit';

/**
This class takes an observable which vends QueryResultSets and adapts it so that
you can make it the data source of a MultiselectList.

When the MultiselectList is refactored to take an Observable, this class should
go away!
*/
export default class ObservableListDataSource extends ListTabular.DataSource {
  constructor(resultSetObservable, setRetainedRange) {
    super();
    this._$resultSetObservable = resultSetObservable;
    this._setRetainedRange = setRetainedRange;
    this._countEstimate = -1;
    this._resultSet = null;
    this._resultDesiredLast = null;

    // Wait until a retained range is set before subscribing to result sets
  }

  _attach = () => {
    this._subscription = this._$resultSetObservable.subscribe(nextResultSet => {
      if (nextResultSet.range().end === this._resultDesiredLast) {
        this._countEstimate = Math.max(this._countEstimate, nextResultSet.range().end);
      } else {
        this._countEstimate = nextResultSet.range().end;
      }

      const previousResultSet = this._resultSet;
      this._resultSet = nextResultSet;

      // If the result set is derived from a query, remove any items in the selection
      // that do not match the query. This ensures that items "removed from the view"
      // are removed from the selection.
      const query = nextResultSet.query();
      if (query) {
        this.selection.removeItemsNotMatching(query.matchers());
      }

      this.trigger({ previous: previousResultSet, next: nextResultSet });
    });
  };

  setRetainedRange({ start, end }) {
    this._resultDesiredLast = end;
    this._setRetainedRange({ start, end });
    if (!this._subscription) {
      this._attach();
    }
  }

  // Retrieving Data

  count() {
    return this._countEstimate;
  }

  loaded() {
    return this._resultSet !== null;
  }

  empty = () => {
    return !this._resultSet || this._resultSet.empty();
  };

  get = offset => {
    if (!this._resultSet) {
      return null;
    }
    return this._resultSet.modelAtOffset(offset);
  };

  getById(id) {
    if (!this._resultSet) {
      return null;
    }
    return this._resultSet.modelWithId(id);
  }

  indexOfId(id) {
    if (!this._resultSet || !id) {
      return -1;
    }
    return this._resultSet.offsetOfId(id);
  }

  itemsCurrentlyInViewMatching(matchFn) {
    if (!this._resultSet) {
      return [];
    }
    return this._resultSet.models().filter(matchFn);
  }

  cleanup() {
    if (this._subscription) {
      this._subscription.dispose();
    }
    return super.cleanup();
  }
}
