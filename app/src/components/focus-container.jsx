import { React, PropTypes, FocusedContentStore, Actions } from 'mailspring-exports';
import { FluxContainer } from 'mailspring-component-kit';

export default class FocusContainer extends React.Component {
  static displayName = 'FocusContainer';
  static propTypes = {
    children: PropTypes.element,
    collection: PropTypes.string,
  };

  getStateFromStores = () => {
    const { collection } = this.props;
    return {
      focused: FocusedContentStore.focused(collection),
      focusedId: FocusedContentStore.focusedId(collection),
      keyboardCursor: FocusedContentStore.keyboardCursor(collection),
      keyboardCursorId: FocusedContentStore.keyboardCursorId(collection),
      onFocusItem: item => Actions.setFocus({ collection: collection, item: item }),
      onSetCursorPosition: item =>
        Actions.setCursorPosition({ collection: collection, item: item }),
    };
  };

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
