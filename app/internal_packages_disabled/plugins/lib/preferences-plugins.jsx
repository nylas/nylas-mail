import React from 'react';

import TabsStore from './tabs-store';
import Tabs from './tabs';

class PluginsView extends React.Component {
  static displayName = 'PluginsView';

  static containerStyles = {
    minWidth: 500,
    maxWidth: 99999,
  };

  constructor() {
    super();
    this.state = this._getStateFromStores();
  }

  componentDidMount() {
    this._unsubscribers = [];
    this._unsubscribers.push(TabsStore.listen(this._onChange));
  }

  componentWillUnmount() {
    this._unsubscribers.forEach(unsubscribe => unsubscribe());
  }

  _getStateFromStores() {
    return { tabIndex: TabsStore.tabIndex() };
  }

  _onChange = () => {
    this.setState(this._getStateFromStores());
  };

  render() {
    const PluginsTabComponent = Tabs[this.state.tabIndex].component;
    return (
      <div className="plugins-view">
        <PluginsTabComponent />
      </div>
    );
  }
}

export default PluginsView;
