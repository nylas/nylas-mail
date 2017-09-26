import { ipcRenderer } from 'electron';
import { BadgeStore } from 'mailspring-exports';
import SystemTrayIconStore from '../lib/system-tray-icon-store';

const { INBOX_ZERO_ICON, INBOX_UNREAD_ICON, INBOX_UNREAD_ALT_ICON } = SystemTrayIconStore;

describe('SystemTrayIconStore', function systemTrayIconStore() {
  beforeEach(() => {
    spyOn(ipcRenderer, 'send');
    this.iconStore = new SystemTrayIconStore();
  });

  function getCallData() {
    const { args } = ipcRenderer.send.calls[0];
    return { iconPath: args[1], isTemplateImg: args[3] };
  }

  describe('_getIconImageData', () => {
    it('shows inbox zero icon when isInboxZero and window is focused', () => {
      const { iconPath, isTemplateImg } = this.iconStore._getIconImageData(true, false);
      expect(iconPath).toBe(INBOX_ZERO_ICON);
      expect(isTemplateImg).toBe(true);
    });

    it('shows inbox zero icon when isInboxZero and window is blurred', () => {
      const { iconPath, isTemplateImg } = this.iconStore._getIconImageData(true, true);
      expect(iconPath).toBe(INBOX_ZERO_ICON);
      expect(isTemplateImg).toBe(true);
    });

    it('shows inbox full icon when not isInboxZero and window is focused', () => {
      const { iconPath, isTemplateImg } = this.iconStore._getIconImageData(false, false);
      expect(iconPath).toBe(INBOX_UNREAD_ICON);
      expect(isTemplateImg).toBe(true);
    });

    it('shows inbox full /alt/ icon when not isInboxZero and window is blurred', () => {
      const { iconPath, isTemplateImg } = this.iconStore._getIconImageData(false, true);
      expect(iconPath).toBe(INBOX_UNREAD_ALT_ICON);
      expect(isTemplateImg).toBe(false);
    });
  });

  describe('updating the icon based on focus and blur', () => {
    it('always shows inbox full icon when the window gets focused', () => {
      spyOn(BadgeStore, 'total').andReturn(1);
      this.iconStore._onWindowFocus();
      const { iconPath } = getCallData();
      expect(iconPath).toBe(INBOX_UNREAD_ICON);
    });

    it('shows inbox full /alt/ icon ONLY when window is currently blurred and total count changes', () => {
      this.iconStore._windowBlurred = false;
      this.iconStore._onWindowBlur();
      expect(ipcRenderer.send).not.toHaveBeenCalled();

      // BadgeStore triggers a change
      spyOn(BadgeStore, 'total').andReturn(1);
      this.iconStore._updateIcon();

      const { iconPath } = getCallData();
      expect(iconPath).toBe(INBOX_UNREAD_ALT_ICON);
    });

    it('does not show inbox full /alt/ icon when window is currently focused and total count changes', () => {
      this.iconStore._windowBlurred = false;

      // BadgeStore triggers a change
      spyOn(BadgeStore, 'total').andReturn(1);
      this.iconStore._updateIcon();

      const { iconPath } = getCallData();
      expect(iconPath).toBe(INBOX_UNREAD_ICON);
    });
  });
});
