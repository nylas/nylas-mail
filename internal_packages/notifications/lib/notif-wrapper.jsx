import _ from 'underscore';
import {React, ReactDOM} from 'nylas-exports'
import {InjectedComponentSet} from 'nylas-component-kit'

const ROLE = "RootSidebar:Notifications";

export default class NotifWrapper extends React.Component {
  static displayName = 'NotifWrapper';

  componentDidMount() {
    this.observer = new MutationObserver(this.update);
    this.observer.observe(ReactDOM.findDOMNode(this), {childList: true})
    this.update() // Necessary if notifications are already mounted
  }

  componentWillUnmount() {
    this.observer.disconnect();
  }

  update = () => {
    const className = "highest-priority";
    const node = ReactDOM.findDOMNode(this);

    const oldHighestPriorityElems = node.querySelectorAll(`.${className}`);
    for (const oldElem of oldHighestPriorityElems) {
      oldElem.classList.remove(className)
    }

    const elemsWithPriority = node.querySelectorAll("[data-priority]")
    if (elemsWithPriority.length === 0) {
      return;
    }

    const highestPriorityElem = _.max(elemsWithPriority,
        (elem) => parseInt(elem.dataset.priority, 10))

    highestPriorityElem.classList.add(className);
  }

  render() {
    return (
      <InjectedComponentSet
        className="notifications"
        matching={{role: ROLE}}
        direction="column"
        containersRequired={false}
      />
    )
  }
}
