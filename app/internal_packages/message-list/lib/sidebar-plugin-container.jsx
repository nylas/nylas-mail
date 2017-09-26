import { React, PropTypes, FocusedContactsStore } from 'mailspring-exports';
import { InjectedComponentSet } from 'mailspring-component-kit';

class FocusedContactStorePropsContainer extends React.Component {
  static displayName = 'FocusedContactStorePropsContainer';

  constructor(props) {
    super(props);
    this.state = this._getStateFromStores();
  }

  componentDidMount() {
    this.unsubscribe = FocusedContactsStore.listen(this._onChange);
  }

  componentWillUnmount() {
    this.unsubscribe();
  }

  _onChange = () => {
    this.setState(this._getStateFromStores());
  };

  _getStateFromStores() {
    return {
      sortedContacts: FocusedContactsStore.sortedContacts(),
      focusedContact: FocusedContactsStore.focusedContact(),
      focusedContactThreads: FocusedContactsStore.focusedContactThreads(),
    };
  }

  render() {
    let classname = 'sidebar-section';
    let inner = null;
    if (this.state.focusedContact) {
      classname += ' visible';
      inner = React.cloneElement(this.props.children, this.state);
    }
    return <div className={classname}>{inner}</div>;
  }
}

const SidebarPluginContainerInner = props => {
  return (
    <InjectedComponentSet
      className="sidebar-contact-card"
      key={props.focusedContact.email}
      matching={{ role: 'MessageListSidebar:ContactCard' }}
      direction="column"
      exposedProps={{
        contact: props.focusedContact,
        contactThreads: props.focusedContactThreads,
      }}
    />
  );
};

SidebarPluginContainerInner.propTypes = {
  focusedContact: PropTypes.object,
  focusedContactThreads: PropTypes.array,
};

export default class SidebarPluginContainer extends React.Component {
  static displayName = 'SidebarPluginContainer';

  static containerStyles = {
    order: 1,
    flexShrink: 0,
    minWidth: 200,
    maxWidth: 300,
  };

  render() {
    return (
      <FocusedContactStorePropsContainer>
        <SidebarPluginContainerInner />
      </FocusedContactStorePropsContainer>
    );
  }
}
