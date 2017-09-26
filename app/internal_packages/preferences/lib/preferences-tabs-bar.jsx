import React from 'react';
import PropTypes from 'prop-types';
import fs from 'fs';
import classNames from 'classnames';

import { Flexbox, RetinaImg } from 'mailspring-component-kit';
import { Actions, PreferencesUIStore, Utils } from 'mailspring-exports';

class PreferencesTabItem extends React.Component {
  static displayName = 'PreferencesTabItem';

  static propTypes = {
    selection: PropTypes.shape({
      accountId: PropTypes.string,
      tabId: PropTypes.string,
    }).isRequired,
    tabItem: PropTypes.instanceOf(PreferencesUIStore.TabItem).isRequired,
  };

  _onClick = () => {
    Actions.switchPreferencesTab(this.props.tabItem.tabId);
  };

  _onClickAccount = (event, accountId) => {
    Actions.switchPreferencesTab(this.props.tabItem.tabId, { accountId });
    event.stopPropagation();
  };

  render() {
    const { selection, tabItem } = this.props;
    const { tabId, displayName } = tabItem;
    const classes = classNames({
      item: true,
      active: tabId === selection.tabId,
    });

    let path = `icon-preferences-${displayName.toLowerCase().replace(' ', '-')}.png`;
    if (!fs.existsSync(Utils.imageNamed(path))) {
      path = 'icon-preferences-general.png';
    }
    const icon = (
      <RetinaImg className="tab-icon" name={path} mode={RetinaImg.Mode.ContentPreserve} />
    );

    return (
      <div className={classes} onClick={this._onClick}>
        {icon}
        <div className="name">{displayName}</div>
      </div>
    );
  }
}

class PreferencesTabsBar extends React.Component {
  static displayName = 'PreferencesTabsBar';

  static propTypes = {
    tabs: PropTypes.array.isRequired,
    selection: PropTypes.shape({
      accountId: PropTypes.string,
      tabId: PropTypes.string,
    }).isRequired,
  };

  renderTabs() {
    return this.props.tabs.map(tabItem => (
      <PreferencesTabItem key={tabItem.tabId} tabItem={tabItem} selection={this.props.selection} />
    ));
  }

  render() {
    return (
      <div className="container-preference-tabs">
        <Flexbox direction="row" className="preferences-tabs">
          <div style={{ flex: 1 }} />
          {this.renderTabs()}
          <div style={{ flex: 1 }} />
        </Flexbox>
      </div>
    );
  }
}

export default PreferencesTabsBar;
