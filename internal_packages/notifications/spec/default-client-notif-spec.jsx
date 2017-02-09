import {mount} from 'enzyme';
import proxyquire from 'proxyquire';
import {React} from 'nylas-exports';

let stubIsRegistered = null;
let stubRegister = () => {};
const patched = proxyquire('../lib/items/default-client-notif',
  {
    'nylas-exports': {
      DefaultClientHelper: class {
        constructor() {
          this.isRegisteredForURLScheme = (urlScheme, callback) => { callback(stubIsRegistered) };
          this.registerForURLScheme = (urlScheme) => { stubRegister(urlScheme) };
        }
      },
    },
  }
)
const DefaultClientNotification = patched.default;
const SETTINGS_KEY = 'nylas.mailto.prompted-about-default';

describe("DefaultClientNotif", function DefaultClientNotifTests() {
  describe("when N1 isn't the default mail client", () => {
    beforeEach(() => {
      stubIsRegistered = false;
    })
    describe("when the user has already responded", () => {
      beforeEach(() => {
        spyOn(NylasEnv.config, "get").andReturn(true);
        this.notif = mount(<DefaultClientNotification />);
        expect(NylasEnv.config.get).toHaveBeenCalledWith(SETTINGS_KEY);
      });
      it("renders nothing", () => {
        expect(this.notif.find('.notification').exists()).toEqual(true);
      });
    });

    describe("when the user has yet to respond", () => {
      beforeEach(() => {
        spyOn(NylasEnv.config, "get").andReturn(false);
        this.notif = mount(<DefaultClientNotification />);
        expect(NylasEnv.config.get).toHaveBeenCalledWith(SETTINGS_KEY);
      });
      it("renders a notification", () => {
        expect(this.notif.find('.notification').exists()).toEqual(false);
      });

      it("allows the user to set N1 as the default client", () => {
        let scheme = null;
        stubRegister = (urlScheme) => { scheme = urlScheme };
        this.notif.find('#action-0').simulate('click'); // Expects first action to set N1 as default
        expect(scheme).toEqual('mailto');
      });

      it("allows the user to decline", () => {
        spyOn(NylasEnv.config, "set")
        this.notif.find('#action-1').simulate('click'); // Expects second action to decline
        expect(NylasEnv.config.set).toHaveBeenCalledWith(SETTINGS_KEY, true);
      });
    })
  });

  describe("when N1 is the default mail client", () => {
    beforeEach(() => {
      stubIsRegistered = true;
      this.notif = mount(<DefaultClientNotification />)
    })
    it("renders nothing", () => {
      expect(this.notif.find('.notification').exists()).toEqual(true);
    });
  })
});
