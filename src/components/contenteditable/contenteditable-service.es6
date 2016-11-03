// These are additions to the Contenteditable component that are tightly
// coupled to the props, state, and innerState of the parent component.

// They're designed to better separate concerns of the Contenteditable
export default class ContenteditableService {
  constructor({data, methods}) {
    this.data = data;
    this.methods = methods;
    ({props: this.props, state: this.state, innerState: this.innerState} = this.data);
    ({setInnerState: this.setInnerState, dispatchEventToExtensions: this.dispatchEventToExtensions} = this.methods);
  }

  setData({props, state, innerState}) {
    this.props = props;
    this.state = state;
    this.innerState = innerState;
  }

  eventHandlers() {
    return {};
  }

  teardown() {
  }
}
