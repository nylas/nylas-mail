import {
  React,
  // The ComponentRegistry manages all React components in N1.
  ComponentRegistry,
  // A `Store` is a Flux component which contains all business logic and data
  // models to be consumed by React components to render markup.
  MessageStore,
  Actions,
} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit'
import {PLUGIN_ID} from './phishing-detection-constants'

// Notice that this file is `main.cjsx` rather than `main.coffee`. We use the
// `.cjsx` filetype because we use the CJSX DSL to describe markup for React to
// render. Without the CJSX, we could just name this file `main.coffee` instead.
class PhishingIndicator extends React.Component {

  // Adding a displayName to a React component helps for debugging.
  static displayName = 'PhishingIndicator';

  constructor() {
    super();
    this.state = {
      message: MessageStore.items()[0],
    };
  }
  componentDidMount() {
    this._unlisten = MessageStore.listen(this._onMessagesChanged);
  }

  componentWillUnmount() {
    if (this._unlisten) {
      this._unlisten();
    }
  }

  _onMessagesChanged = () => {
    this.setState({
      message: MessageStore.items()[0],
    });
  }

  _onHide = () => {
    const {message} = this.state;
    const metadata = message.metadataForPluginId(PLUGIN_ID) || {};

    metadata.hide = true;
    Actions.setMetadata(message, PLUGIN_ID, metadata);
  }

  // A React component's `render` method returns a virtual DOM element described
  // in CJSX. `render` is deterministic: with the same input, it will always
  // render the same output. Here, the input is provided by @isPhishingAttempt.
  // `@state` and `@props` are popular inputs as well.
  render() {
    const {message} = this.state;

    // This package's strategy to ascertain whether or not the email is a
    // phishing attempt boils down to checking the `replyTo` attributes on
    // `Message` models from `MessageStore`.
    if (message && message.replyTo && message.replyTo.length !== 0) {
      // Don't show the phishing indicator when the user hided it before
      const metadata = message.metadataForPluginId(PLUGIN_ID);
      if (!metadata || metadata.hide !== true) {
        const from = message.from[0].email;
        const replyTo = message.replyTo[0].email;
        if (replyTo !== from) {
          return (
            <div className="phishingIndicator">
              <b>This message looks suspicious!</b>
              <RetinaImg
                className="x"
                name="label-x.png"
                mode={RetinaImg.Mode.ContentIsMask}
                onClick={this._onHide}/>
              <div className="description">{`It originates from ${from} but replies will go to ${replyTo}.`}</div>
            </div>
          );
        }
      }
    }

    return null;
  }
}

export function activate() {
  ComponentRegistry.register(PhishingIndicator, {
    role: 'MessageListHeaders',
  });
}

export function serialize() {

}

export function deactivate() {
  ComponentRegistry.unregister(PhishingIndicator);
}
