import React from 'react';
import classNames from 'classnames';
import PropTypes from 'prop-types';

import Tabs from './tabs';
import TabsStore from './tabs-store';
import PluginsActions from './plugins-actions';

class PluginsTabs extends React.Component {
  static displayName = 'PluginsTabs';

  static propTypes = {
    onChange: PropTypes.Func,
  };

  static containerRequired = false;

  static containerStyles = {
    minWidth: 200,
    maxWidth: 290,
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
    return {
      tabIndex: TabsStore.tabIndex(),
    };
  }

  _onChange = () => {
    this.setState(this._getStateFromStores());
  };

  _renderItems() {
    return Tabs.map(({ name, key, icon }, idx) => {
      const classes = classNames({
        tab: true,
        active: idx === this.state.tabIndex,
      });
      return (
        <li key={key} className={classes} onClick={() => PluginsActions.selectTabIndex(idx)}>
          {name}
        </li>
      );
    });
  }

  render() {
    return <ul className="plugins-view-tabs">{this._renderItems()}</ul>;
  }
}

export default PluginsTabs;
