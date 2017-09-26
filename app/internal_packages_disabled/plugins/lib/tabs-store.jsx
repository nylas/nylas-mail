import Reflux from 'reflux';

import PluginsActions from './plugins-actions';

const TabsStore = Reflux.createStore({
  init: function init() {
    this._tabIndex = 0;
    this.listenTo(PluginsActions.selectTabIndex, this._onTabIndexChanged);
  },

  // Getters

  tabIndex: function tabIndex() {
    return this._tabIndex;
  },

  // Action Handlers

  _onTabIndexChanged: function _onTabIndexChanged(idx) {
    this._tabIndex = idx;
    this.trigger(this);
  },
});

export default TabsStore;
