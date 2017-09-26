import { mount } from 'enzyme';
import proxyquire from 'proxyquire';
import { React } from 'mailspring-exports';

let stubUpdaterState = null;
let stubUpdaterReleaseVersion = null;
let ipcSendArgs = null;

const patched = proxyquire('../lib/items/update-notification', {
  electron: {
    ipcRenderer: {
      send: (...args) => {
        ipcSendArgs = args;
      },
    },
    remote: {
      getGlobal: () => {
        return {
          autoUpdateManager: {
            releaseVersion: stubUpdaterReleaseVersion,
            getState: () => stubUpdaterState,
            getReleaseDetails: () => {
              return {
                releaseVersion: stubUpdaterReleaseVersion,
                releaseNotes: 'A new version is available!',
              };
            },
          },
        };
      },
    },
  },
});

const UpdateNotification = patched.default;

describe('UpdateNotification', function describeBlock() {
  beforeEach(() => {
    stubUpdaterState = 'idle';
    stubUpdaterReleaseVersion = undefined;
    ipcSendArgs = null;
  });

  describe('mounting', () => {
    it('should display a notification immediately if one is available', () => {
      stubUpdaterState = 'update-available';
      const notif = mount(<UpdateNotification />);
      expect(notif.find('.notification').exists()).toEqual(true);
    });

    it('should not display a notification if no update is avialable', () => {
      stubUpdaterState = 'no-update-available';
      const notif = mount(<UpdateNotification />);
      expect(notif.find('.notification').exists()).toEqual(false);
    });

    it('should listen for `window:update-available`', () => {
      spyOn(AppEnv, 'onUpdateAvailable').andCallThrough();
      mount(<UpdateNotification />);
      expect(AppEnv.onUpdateAvailable).toHaveBeenCalled();
    });
  });

  describe('displayNotification', () => {
    it('should include the version if one is provided', () => {
      stubUpdaterState = 'update-available';
      stubUpdaterReleaseVersion = '0.515.0-123123';
      const notif = mount(<UpdateNotification />);
      expect(
        notif
          .find('.title')
          .text()
          .indexOf('0.515.0-123123') >= 0
      ).toBe(true);
    });

    describe('when the action is taken', () => {
      it('should fire the `application:install-update` IPC event', () => {
        stubUpdaterState = 'update-available';
        const notif = mount(<UpdateNotification />);
        notif.find('#action-0').simulate('click'); // Expects the first action to be the install action
        expect(ipcSendArgs).toEqual(['command', 'application:install-update']);
      });
    });
  });
});
