import { mount } from 'enzyme';
import proxyquire from 'proxyquire';
import { React } from 'mailspring-exports';

let stubIsRegistered = null;
let stubRegister = () => {};
const patched = proxyquire('../lib/items/default-client-notif', {
  'mailspring-exports': {
    DefaultClientHelper: class {
      constructor() {
        this.isRegisteredForURLScheme = (urlScheme, callback) => {
          callback(stubIsRegistered);
        };
        this.registerForURLScheme = urlScheme => {
          stubRegister(urlScheme);
        };
      }
    },
  },
});
const DefaultClientNotification = patched.default;
const SETTINGS_KEY = 'mailto.prompted-about-default';

describe('DefaultClientNotif', function DefaultClientNotifTests() {
  describe("when Mailspring isn't the default mail client", () => {
    beforeEach(() => {
      stubIsRegistered = false;
    });
    describe('when the user has already responded', () => {
      beforeEach(() => {
        spyOn(AppEnv.config, 'get').andReturn(true);
        this.notif = mount(<DefaultClientNotification />);
        expect(AppEnv.config.get).toHaveBeenCalledWith(SETTINGS_KEY);
      });
      it('renders nothing', () => {
        expect(this.notif.find('.notification').exists()).toEqual(false);
      });
    });

    describe('when the user has yet to respond', () => {
      beforeEach(() => {
        spyOn(AppEnv.config, 'get').andReturn(false);
        this.notif = mount(<DefaultClientNotification />);
        expect(AppEnv.config.get).toHaveBeenCalledWith(SETTINGS_KEY);
      });
      it('renders a notification', () => {
        expect(this.notif.find('.notification').exists()).toEqual(true);
      });

      it('allows the user to set Mailspring as the default client', () => {
        let scheme = null;
        stubRegister = urlScheme => {
          scheme = urlScheme;
        };
        this.notif.find('#action-0').simulate('click'); // Expects first action to set Mailspring as default
        expect(scheme).toEqual('mailto');
      });

      it('allows the user to decline', () => {
        spyOn(AppEnv.config, 'set');
        this.notif.find('#action-1').simulate('click'); // Expects second action to decline
        expect(AppEnv.config.set).toHaveBeenCalledWith(SETTINGS_KEY, true);
      });
    });
  });

  describe('when Mailspring is the default mail client', () => {
    beforeEach(() => {
      stubIsRegistered = true;
      this.notif = mount(<DefaultClientNotification />);
    });
    it('renders nothing', () => {
      expect(this.notif.find('.notification').exists()).toEqual(false);
    });
  });
});
