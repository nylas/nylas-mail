import { React, Actions, MessageStore, FocusedPerspectiveStore } from 'mailspring-exports';

export default class MessageListHiddenMessagesToggle extends React.Component {
  static displayName = 'MessageListHiddenMessagesToggle';

  constructor() {
    super();
    this.state = {
      numberOfHiddenItems: MessageStore.numberOfHiddenItems(),
    };
  }

  componentDidMount() {
    this._unlisten = MessageStore.listen(() => {
      this.setState({
        numberOfHiddenItems: MessageStore.numberOfHiddenItems(),
      });
    });
  }

  componentWillUnmount() {
    this._unlisten();
  }

  render() {
    const { numberOfHiddenItems } = this.state;
    if (numberOfHiddenItems === 0) {
      return <span />;
    }

    const viewing = FocusedPerspectiveStore.current().categoriesSharedRole();
    let message = null;

    if (MessageStore.FolderNamesHiddenByDefault.includes(viewing)) {
      if (numberOfHiddenItems > 1) {
        message = `There are ${numberOfHiddenItems} more messages in this thread that are not in spam or trash.`;
      } else {
        message = `There is one more message in this thread that is not in spam or trash.`;
      }
    } else {
      if (numberOfHiddenItems > 1) {
        message = `${numberOfHiddenItems} messages in this thread are hidden because it was moved to trash or spam.`;
      } else {
        message = `One message in this thread is hidden because it was moved to trash or spam.`;
      }
    }

    return (
      <div className="show-hidden-messages">
        {message}
        <a
          onClick={function toggle() {
            Actions.toggleHiddenMessages();
          }}
        >
          Show all messages
        </a>
      </div>
    );
  }
}

MessageListHiddenMessagesToggle.containerRequired = false;
