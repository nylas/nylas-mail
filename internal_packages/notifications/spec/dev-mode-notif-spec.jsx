import {mount} from 'enzyme';
import {React} from 'nylas-exports';
import DevModeNotification from '../lib/items/dev-mode-notif';

describe("DevModeNotif", function DevModeNotifTests() {
  describe("When the window is in dev mode", () => {
    beforeEach(() => {
      spyOn(NylasEnv, "inDevMode").andReturn(true);
      this.notif = mount(<DevModeNotification />);
    })
    it("displays a notification", () => {
      expect(this.notif.find('.notification').exists()).toEqual(false);
    })
  })

  describe("When the window is not in dev mode", () => {
    beforeEach(() => {
      spyOn(NylasEnv, "inDevMode").andReturn(false);
      this.notif = mount(<DevModeNotification />);
    })
    it("doesn't display a notification", () => {
      expect(this.notif.find('.notification').exists()).toEqual(true);
    })
  })
});
