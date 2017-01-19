/* eslint global-require: 0 */
import Attributes from '../attributes';
import QueryRange from './query-range';
import Utils from './utils';

const {Matcher, AttributeJoinedData, AttributeCollection} = Attributes;

/*
Public: ModelQuery exposes an ActiveRecord-style syntax for building database queries
that return models and model counts. Model queries are returned from the factory methods
{DatabaseStore::find}, {DatabaseStore::findBy}, {DatabaseStore::findAll}, and {DatabaseStore::count}, and are the primary interface for retrieving data
from the app's local cache.

ModelQuery does not allow you to modify the local cache. To create, update or
delete items from the local cache, see {DatabaseStore::persistModel}
and {DatabaseStore::unpersistModel}.

**Simple Example:** Fetch a thread

```coffee
query = DatabaseStore.find(Thread, '123a2sc1ef4131')
query.then (thread) ->
  // thread or null
```

**Advanced Example:** Fetch 50 threads in the inbox, in descending order

```coffee
query = DatabaseStore.findAll(Thread)
query.where([Thread.attributes.categories.contains('label-id')])
     .order([Thread.attributes.lastMessageReceivedTimestamp.descending()])
     .limit(100).offset(50)
     .then (threads) ->
  // array of threads
```

Section: Database
*/
export default class ModelQuery {

  // Public
  // - `class` A {Model} class to query
  // - `database` (optional) An optional reference to a {DatabaseStore} the
  //   query will be executed on.
  //
  constructor(klass, database) {
    this._klass = klass;
    this._database = database || require('./database-store').default;
    this._matchers = [];
    this._orders = [];
    this._background = false;
    this._backgroundable = true;
    this._distinct = false;
    this._range = QueryRange.infinite();
    this._returnOne = false;
    this._returnIds = false;
    this._includeJoinedData = [];
    this._count = false;
  }

  clone() {
    const q = new ModelQuery(this._klass, this._database).where(this._matchers).order(this._orders);
    q._orders = [].concat(this._orders);
    q._includeJoinedData = [].concat(this._includeJoinedData);
    q._range = this._range.clone();
    q._background = this._background;
    q._backgroundable = this._backgroundable;
    q._distinct = this._distinct;
    q._returnOne = this._returnOne;
    q._returnIds = this._returnIds;
    q._count = this._count;
    return q;
  }

  distinct() {
    this._distinct = true;
    return this;
  }

  background() {
    if (!this._backgroundable) {
      throw new Error("Queries within transactions cannot be moved to the background.");
    }
    this._background = true;
    return this;
  }

  markNotBackgroundable() {
    this._backgroundable = false;
    return this;
  }

  // Public: Add one or more where clauses to the query
  //
  // - `matchers` An {Array} of {Matcher} objects that add where clauses to the underlying query.
  //
  // This method is chainable.
  //
  where(matchers) {
    this._assertNotFinalized();

    if (matchers instanceof Matcher) {
      this._matchers.push(matchers);
    } else if (matchers instanceof Array) {
      for (const m of matchers) {
        if (!(m instanceof Matcher)) {
          throw new Error("You must provide instances of `Matcher`");
        }
      }
      this._matchers = this._matchers.concat(matchers);
    } else if (matchers instanceof Object) {
      // Support a shorthand format of {id: '123', accountId: '123'}
      for (const key of Object.keys(matchers)) {
        const value = matchers[key];
        const attr = this._klass.attributes[key];
        if (!attr) {
          const msg = `Cannot create where clause \`${key}:${value}\`. ${key} is not an attribute of ${this._klass.name}`;
          throw new Error(msg);
        }

        if (value instanceof Array) {
          this._matchers.push(attr.in(value));
        } else {
          this._matchers.push(attr.equal(value));
        }
      }
    }
    return this;
  }

  whereAny(matchers) {
    this._assertNotFinalized();
    this._matchers.push(new Matcher.Or(matchers));
    return this;
  }

  search(query) {
    this._assertNotFinalized();
    this._matchers.push(new Matcher.Search(query));
    return this;
  }

  structuredSearch(query) {
    this._assertNotFinalized();
    this._matchers.push(new Matcher.StructuredSearch(query));
    return this;
  }

  // Public: Include specific joined data attributes in result objects.
  // - `attr` A {AttributeJoinedData} that you want to be populated in
  //  the returned models. Note: This results in a LEFT OUTER JOIN.
  //  See {AttributeJoinedData} for more information.
  //
  // This method is chainable.
  //
  include(attr) {
    this._assertNotFinalized();
    if (!(attr instanceof AttributeJoinedData)) {
      throw new Error("query.include() must be called with a joined data attribute");
    }
    this._includeJoinedData.push(attr);
    return this;
  }

  // Public: Include all of the available joined data attributes in returned models.
  //
  // This method is chainable.
  //
  includeAll() {
    this._assertNotFinalized()
    for (const key of Object.keys(this._klass.attributes)) {
      const attr = this._klass.attributes[key];
      if (attr instanceof AttributeJoinedData) {
        this.include(attr);
      }
    }
    return this;
  }

  // Public: Apply a sort order to the query.
  // - `orders` An {Array} of one or more {SortOrder} objects that determine the
  //   sort order of returned models.
  //
  // This method is chainable.
  //
  order(ordersOrOrder) {
    this._assertNotFinalized();
    const orders = (ordersOrOrder instanceof Array) ? ordersOrOrder : [ordersOrOrder];
    this._orders = this._orders.concat(orders);
    return this;
  }

  // Public: Set the `singular` flag - only one model will be returned from the
  // query, and a `LIMIT 1` clause will be used.
  //
  // This method is chainable.
  //
  one() {
    this._assertNotFinalized();
    this._returnOne = true;
    return this;
  }

  // Public: Limit the number of query results.
  //
  // - `limit` {Number} The number of models that should be returned.
  //
  // This method is chainable.
  //
  limit(limit) {
    this._assertNotFinalized()
    if (this._returnOne && limit > 1) {
      throw new Error("Cannot use limit > 1 with one()");
    }
    this._range = this._range.clone();
    this._range.limit = limit;
    return this;
  }

  // Public:
  //
  // - `offset` {Number} The start offset of the query.
  //
  // This method is chainable.
  //
  offset(offset) {
    this._assertNotFinalized();
    this._range = this._range.clone();
    this._range.offset = offset;
    return this;
  }

  // Public:
  //
  // A convenience method for setting both limit and offset given a desired page size.
  //
  page(start, end, pageSize = 50, pagePadding = 100) {
    const roundToPage = (n) => Math.max(0, Math.floor(n / pageSize) * pageSize)
    this.offset(roundToPage(start - pagePadding));
    this.limit(roundToPage((end - start) + pagePadding * 2));
    return this;
  }

  // Public: Set the `count` flag - instead of returning inflated models,
  // the query will return the result `COUNT`.
  //
  // This method is chainable.
  //
  count() {
    this._assertNotFinalized();
    this._count = true;
    return this;
  }

  idsOnly() {
    this._assertNotFinalized();
    this._returnIds = true;
    return this;
  }

  // Query Execution

  // Public: Short-hand syntax that calls run().then(fn) with the provided function.
  //
  // Returns a {Promise} that resolves with the Models returned by the
  // query, or rejects with an error from the Database layer.
  //
  then(next) {
    return this.run(this).then(next);
  }

  // Public: Returns a {Promise} that resolves with the Models returned by the
  // query, or rejects with an error from the Database layer.
  //
  run() {
    return this._database.run(this);
  }

  inflateResult(result) {
    if (!result) {
      return null;
    }

    if (this._count) {
      return result[0].count / 1;
    }
    if (this._returnIds) {
      return result.map(row => row.id);
    }

    try {
      return result.map((row) => {
        const json = JSON.parse(row.data, Utils.registeredObjectReviver)
        const object = (new this._klass()).fromJSON(json);
        for (const attrName of Object.keys(this._klass.attributes)) {
          const attr = this._klass.attributes[attrName];
          if (!attr.needsColumn() || !attr.loadFromColumn) {
            continue;
          }
          object[attr.modelKey] = attr.fromColumn(row[attr.jsonKey]);
        }
        for (const attr of this._includeJoinedData) {
          let value = row[attr.jsonKey];
          if (value === AttributeJoinedData.NullPlaceholder) {
            value = null;
          }
          object[attr.modelKey] = value;
        }
        return object;
      });
    } catch (error) {
      throw new Error(`Query could not parse the database result. Query: ${this.sql()}, Error: ${error.toString()}`);
    }
  }

  formatResult(inflated) {
    if (this._returnOne) {
      return inflated[0];
    }
    if (this._count) {
      return inflated;
    }
    return [].concat(inflated);
  }

  // Query SQL Building

  // Returns a {String} with the SQL generated for the query.
  //
  sql() {
    this.finalize();

    let result = null;

    if (this._count) {
      result = `COUNT(*) as count`;
    } else if (this._returnIds) {
      result = `\`${this._klass.name}\`.\`id\``;
    } else {
      result = `\`${this._klass.name}\`.\`data\``;
      for (const attrName of Object.keys(this._klass.attributes)) {
        const attr = this._klass.attributes[attrName];
        if (!attr.needsColumn() || !attr.loadFromColumn) {
          continue;
        }
        result += `, ${attr.jsonKey} `;
      }
      this._includeJoinedData.forEach((attr) => {
        result += `, ${attr.selectSQL(this._klass)} `;
      })
    }

    const order = this._count ? '' : this._orderClause();

    let limit = '';
    if (Number.isInteger(this._range.limit)) {
      limit = `LIMIT ${this._range.limit}`;
    } else {
      limit = ''
    }
    if (Number.isInteger(this._range.offset)) {
      limit += ` OFFSET ${this._range.offset}`;
    }

    const distinct = this._distinct ? ' DISTINCT' : '';
    const allMatchers = this.matchersFlattened();

    const joins = allMatchers.filter((matcher) => matcher.attr instanceof AttributeCollection)

    if ((joins.length === 1) && this._canSubselectForJoin(joins[0], allMatchers)) {
      const subSql = this._subselectSQL(joins[0], this._matchers, order, limit);
      return `SELECT${distinct} ${result} FROM \`${this._klass.name}\` WHERE \`id\` IN (${subSql}) ${order}`;
    }

    return `SELECT${distinct} ${result} FROM \`${this._klass.name}\` ${this._whereClause()} ${order} ${limit}`;
  }

  // If one of our matchers requires a join, and the attribute configuration lists
  // all of the other order and matcher attributes in \`joinQueryableBy\`, it means
  // we can make the entire WHERE and ORDER BY on a sub-query, which improves
  // performance considerably vs. finding all results from the join table and then
  // doing the ordering after pulling the results in the main table.
  //
  // Note: This is currently only intended for use in the thread list
  //
  _canSubselectForJoin(matcher, allMatchers) {
    const joinAttribute = matcher.attribute();

    if (!Number.isInteger(this._range.limit)) {
      return false;
    }

    const allMatchersOnJoinTable = allMatchers.every((m) =>
      (m === matcher) || (joinAttribute.joinQueryableBy.includes(m.attr.modelKey)) || (m.attr.modelKey === 'id')
    );
    const allOrdersOnJoinTable = this._orders.every((o) =>
      (joinAttribute.joinQueryableBy.includes(o.attr.modelKey))
    );

    return (allMatchersOnJoinTable && allOrdersOnJoinTable);
  }

  _subselectSQL(returningMatcher, subselectMatchers, order, limit) {
    const returningAttribute = returningMatcher.attribute()

    const table = Utils.tableNameForJoin(this._klass, returningAttribute.itemClass);
    const wheres = subselectMatchers.map(c => c.whereSQL(this._klass)).filter(c => !!c);

    let innerSQL = `SELECT \`id\` FROM \`${table}\` WHERE ${wheres.join(' AND ')} ${order} ${limit}`;
    innerSQL = innerSQL.replace(new RegExp(`\`${this._klass.name}\``, 'g'), `\`${table}\``);
    innerSQL = innerSQL.replace(new RegExp(`\`${returningMatcher.joinTableRef()}\``, 'g'), `\`${table}\``);
    return innerSQL;
  }

  _whereClause() {
    const joins = [];
    this._matchers.forEach((c) => {
      const join = c.joinSQL(this._klass)
      if (join) {
        joins.push(join);
      }
    });

    this._includeJoinedData.forEach((attr) => {
      const join = attr.includeSQL(this._klass)
      if (join) {
        joins.push(join);
      }
    });

    const wheres = [];
    this._matchers.forEach(c => {
      const where = c.whereSQL(this._klass);
      if (where) {
        wheres.push(where)
      }
    });

    let sql = joins.join(' ')
    if (wheres.length > 0) {
      sql += ` WHERE ${wheres.join(' AND ')}`;
    }
    return sql;
  }

  _orderClause() {
    if (this._orders.length === 0) {
      return ''
    }

    let sql = ' ORDER BY '
    this._orders.forEach((sort) => {
      sql += sort.orderBySQL(this._klass);
    });
    return sql;
  }

  // Private: Marks the object as final, preventing any changes to the where
  // clauses, orders, etc.
  finalize() {
    if (this._finalized) {
      return this;
    }

    if (this._orders.length === 0) {
      const natural = this._klass.naturalSortOrder();
      if (natural) {
        this._orders.push(natural);
      }
    }

    if (this._returnOne && !this._range.limit) {
      this.limit(1);
    }

    this._finalized = true;
    return this;
  }

  // Private: Throws an exception if the query has been frozen.
  _assertNotFinalized() {
    if (this._finalized) {
      throw new Error(`ModelQuery: You cannot modify a query after calling \`then\` or \`listen\``);
    }
  }

  // Introspection
  // (These are here to make specs easy)

  matchers() {
    return this._matchers;
  }

  matchersFlattened() {
    const all = []
    const traverse = (matchers) => {
      if (!(matchers instanceof Array)) {
        return;
      }
      for (const m of matchers) {
        if (m.children) {
          traverse(m.children);
        } else {
          all.push(m);
        }
      }
    }
    traverse(this._matchers);
    return all;
  }

  matcherValueForModelKey(key) {
    const matcher = this._matchers.find(m => m.attr.modelKey === key)
    return matcher ? matcher.val : null;
  }

  range() {
    return this._range;
  }

  orderSortDescriptors() {
    return this._orders;
  }

  objectClass() {
    return this._klass.name;
  }
}
