import MutableQuerySubscription from './mutable-query-subscription';
import DatabaseStore from '../stores/database-store';
import RecentlyReadStore from '../stores/recently-read-store';
import Matcher from '../attributes/matcher';
import Thread from '../models/thread';

const buildQuery = categoryIds => {
  const unreadMatchers = new Matcher.And([
    Thread.attributes.categories.containsAny(categoryIds),
    Thread.attributes.unread.equal(true),
    Thread.attributes.inAllMail.equal(true),
  ]);

  const query = DatabaseStore.findAll(Thread).limit(0);

  // The "Unread" view shows all threads which are unread. When you read a thread,
  // it doesn't disappear until you leave the view and come back. This behavior
  // is implemented by keeping track of messages being rea and manually
  // whitelisting them in the query.
  if (RecentlyReadStore.ids.length === 0) {
    query.where(unreadMatchers);
  } else {
    query.where(new Matcher.Or([unreadMatchers, Thread.attributes.id.in(RecentlyReadStore.ids)]));
  }

  return query;
};

export default class UnreadQuerySubscription extends MutableQuerySubscription {
  constructor(categoryIds) {
    super(buildQuery(categoryIds), { emitResultSet: true });
    this._categoryIds = categoryIds;
    this._unlisten = RecentlyReadStore.listen(this.onRecentlyReadChanged);
  }

  onRecentlyReadChanged = () => {
    const { limit, offset } = this._query.range();
    this._query = buildQuery(this._categoryIds)
      .limit(limit)
      .offset(offset);
  };

  onLastCallbackRemoved() {
    this._unlisten();
  }
}
