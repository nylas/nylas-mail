/* eslint global-require:0 */
import MailspringStore from 'mailspring-store';
import FocusedPerspectiveStore from './focused-perspective-store';
import ThreadCountsStore from './thread-counts-store';
import CategoryStore from './category-store';

class BadgeStore extends MailspringStore {
  constructor() {
    super();

    this.listenTo(FocusedPerspectiveStore, this._updateCounts);
    this.listenTo(ThreadCountsStore, this._updateCounts);

    AppEnv.config.onDidChange('core.notifications.countBadge', ({ newValue }) => {
      if (newValue !== 'hide') {
        this._setBadgeForCount();
      } else {
        this._setBadge('');
      }
    });

    this._updateCounts();
  }

  // Public: Returns the number of unread threads in the user's mailbox
  unread() {
    return this._unread;
  }

  total() {
    return this._total;
  }

  _updateCounts = () => {
    let unread = 0;
    let total = 0;

    const accountIds = FocusedPerspectiveStore.current().accountIds;
    for (const cat of CategoryStore.getCategoriesWithRoles(accountIds, 'inbox')) {
      unread += ThreadCountsStore.unreadCountForCategoryId(cat.id);
      total += ThreadCountsStore.totalCountForCategoryId(cat.id);
    }

    if (this._unread === unread && this._total === total) {
      return;
    }
    this._unread = unread;
    this._total = total;
    this._setBadgeForCount();
    this.trigger();
  };

  _setBadgeForCount = () => {
    const badgePref = AppEnv.config.get('core.notifications.countBadge');
    if (!badgePref || badgePref === 'hide') {
      return;
    }
    if (!AppEnv.isMainWindow() && !AppEnv.inSpecMode()) {
      return;
    }

    const count = badgePref === 'unread' ? this._unread : this._total;
    if (count > 999) {
      this._setBadge('999+');
    } else if (count > 0) {
      this._setBadge(`${count}`);
    } else {
      this._setBadge('');
    }
  };

  _setBadge = val => {
    require('electron').ipcRenderer.send('set-badge-value', val);
  };
}

const badgeStore = new BadgeStore();
export default badgeStore;
