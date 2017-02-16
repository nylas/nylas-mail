import React from 'react';
import {FocusedContentStore, Actions} from 'nylas-exports';
import {FluxContainer} from 'nylas-component-kit';

export default class FocusContainer extends React.Component {
  static displayName: 'FocusContainer'
  static propTypes = {
    children: React.PropTypes.element,
    collection: React.PropTypes.string,
  }

  getStateFromStores = () => {
    const {collection} = this.props;
    return {
      focused: FocusedContentStore.focused(collection),
      focusedId: FocusedContentStore.focusedId(collection),
      keyboardCursor: FocusedContentStore.keyboardCursor(collection),
      keyboardCursorId: FocusedContentStore.keyboardCursorId(collection),
      onFocusItem: (item) => Actions.setFocus({collection: collection, item: item}),
      onSetCursorPosition: (item) => Actions.setCursorPosition({collection: collection, item: item}),
    };
  }

  render() {
    return (
      <FluxContainer
        {...this.props}
        stores={[FocusedContentStore]}
        getStateFromStores={this.getStateFromStores}
      >
        {this.props.children}
      </FluxContainer>
    );
  }
}
