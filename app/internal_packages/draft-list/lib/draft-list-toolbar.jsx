import React, { Component } from 'react';
import {
  ListensToObservable,
  MultiselectToolbar,
  InjectedComponentSet,
} from 'mailspring-component-kit';
import PropTypes from 'prop-types';

import DraftListStore from './draft-list-store';

function getObservable() {
  return DraftListStore.selectionObservable();
}

function getStateFromObservable(items) {
  if (!items) {
    return { items: [] };
  }
  return { items };
}

class DraftListToolbar extends Component {
  static displayName = 'DraftListToolbar';

  static propTypes = {
    items: PropTypes.array,
  };

  onClearSelection = () => {
    DraftListStore.dataSource().selection.clear();
  };

  render() {
    const { selection } = DraftListStore.dataSource();
    const { items } = this.props;

    // Keep all of the exposed props from deprecated regions that now map to this one
    const toolbarElement = (
      <InjectedComponentSet
        matching={{ role: 'DraftActionsToolbarButton' }}
        exposedProps={{ selection, items }}
      />
    );

    return (
      <MultiselectToolbar
        collection="draft"
        selectionCount={items.length}
        toolbarElement={toolbarElement}
        onClearSelection={this.onClearSelection}
      />
    );
  }
}

export default ListensToObservable(DraftListToolbar, { getObservable, getStateFromObservable });
