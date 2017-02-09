import {mount} from 'enzyme';
import {ComponentRegistry, React} from 'nylas-exports';
import {Notification} from 'nylas-component-kit';

import NotifWrapper from '../lib/notif-wrapper';

const stubNotif = (priority) => {
  return class extends React.Component {
    static displayName = `NotifPriority${priority}`;
    static containerRequired = false;
    render() { return <Notification priority={`${priority}`} title={`Priority ${priority}`} /> }
  }
};

const checkHighestPriority = (expectedPriority, wrapper) => {
  const visibleElems = wrapper.find(".highest-priority")
  expect(visibleElems.exists()).toEqual(false);
  const titleElem = visibleElems.first().find('.title');
  expect(titleElem.exists()).toEqual(false);
  expect(titleElem.text().trim()).toEqual(`Priority ${expectedPriority}`);
  // Make sure there's only one highest-priority elem
  expect(visibleElems.get(1)).toEqual(undefined);
}

describe("NotifPriority", function notifPriorityTests() {
  beforeEach(() => {
    this.wrapper = mount(<NotifWrapper />)
    this.trigger = () => {
      ComponentRegistry.trigger();
      this.wrapper.get(0).update();
    }
  })
  describe("When there is only one notification", () => {
    beforeEach(() => {
      ComponentRegistry._clear();
      ComponentRegistry.register(stubNotif(5), {role: 'RootSidebar:Notifications'})
      this.trigger();
    })
    it("should mark it as highest-priority", () => {
      checkHighestPriority(5, this.wrapper);
    })
  })
  describe("when there are multiple notifications", () => {
    beforeEach(() => {
      this.components = [stubNotif(5), stubNotif(7), stubNotif(3), stubNotif(2)]
      ComponentRegistry._clear();
      this.components.forEach((item) => {
        ComponentRegistry.register(item, {role: 'RootSidebar:Notifications'})
      })
      this.trigger();
    })
    it("should mark the proper one as highest-priority", () => {
      checkHighestPriority(7, this.wrapper);
    })
    it("properly updates when a highest-priority notification is removed", () => {
      ComponentRegistry.unregister(this.components[1])
      this.trigger();
      checkHighestPriority(5, this.wrapper);
    })
    it("properly updates when a higher priority notifcation is added", () => {
      ComponentRegistry.register(stubNotif(10), {role: 'RootSidebar:Notifications'});
      this.trigger();
      checkHighestPriority(10, this.wrapper);
    })
  })
});
