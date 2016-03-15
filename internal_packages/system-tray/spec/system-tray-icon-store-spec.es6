import {ipcRenderer} from 'electron';
import {UnreadBadgeStore} from 'nylas-exports';
import SystemTrayIconStore from '../lib/system-tray-icon-store';

const {
  INBOX_ZERO_ICON,
  INBOX_UNREAD_ICON,
  INBOX_UNREAD_ALT_ICON,
} = SystemTrayIconStore;


describe('SystemTrayIconStore', ()=> {
  beforeEach(()=> {
    spyOn(ipcRenderer, 'send')
    this.iconStore = new SystemTrayIconStore()
  });

  function getCallData() {
    const {args} = ipcRenderer.send.calls[0]
    return {iconPath: args[1], isTemplateImg: args[3]}
  }

  describe('_getIconImageData', ()=> {
    it('shows inbox zero icon when unread count is 0 and window is focused', ()=> {
      const {iconPath, isTemplateImg} = this.iconStore._getIconImageData(0, false)
      expect(iconPath).toBe(INBOX_ZERO_ICON)
      expect(isTemplateImg).toBe(true)
    });

    it('shows inbox zero icon when unread count is 0 and window is blurred', ()=> {
      const {iconPath, isTemplateImg} = this.iconStore._getIconImageData(0, true)
      expect(iconPath).toBe(INBOX_ZERO_ICON)
      expect(isTemplateImg).toBe(true)
    });

    it('shows inbox full icon when unread count > 0 and window is focused', ()=> {
      const {iconPath, isTemplateImg} = this.iconStore._getIconImageData(1, false)
      expect(iconPath).toBe(INBOX_UNREAD_ICON)
      expect(isTemplateImg).toBe(true)
    });

    it('shows inbox full /alt/ icon when unread count > 0 and window is blurred', ()=> {
      const {iconPath, isTemplateImg} = this.iconStore._getIconImageData(1, true)
      expect(iconPath).toBe(INBOX_UNREAD_ALT_ICON)
      expect(isTemplateImg).toBe(false)
    });
  });

  describe('updating the icon based on focus and blur', ()=> {
    it('always shows inbox full icon when the window gets focused', ()=> {
      spyOn(UnreadBadgeStore, 'count').andReturn(1)
      this.iconStore._onWindowFocus()
      const {iconPath} = getCallData()
      expect(iconPath).toBe(INBOX_UNREAD_ICON)
    });

    it('shows inbox full /alt/ icon ONLY when window is currently blurred and unread count changes', ()=> {
      this.iconStore._windowBlurred = false
      this.iconStore._onWindowBlur()
      expect(ipcRenderer.send).not.toHaveBeenCalled()

      // UnreadBadgeStore triggers a change
      spyOn(UnreadBadgeStore, 'count').andReturn(1)
      this.iconStore._updateIcon()

      const {iconPath} = getCallData()
      expect(iconPath).toBe(INBOX_UNREAD_ALT_ICON)
    });

    it('does not show inbox full /alt/ icon when window is currently focused and unread count changes', ()=> {
      this.iconStore._windowBlurred = false

      // UnreadBadgeStore triggers a change
      spyOn(UnreadBadgeStore, 'count').andReturn(1)
      this.iconStore._updateIcon()

      const {iconPath} = getCallData()
      expect(iconPath).toBe(INBOX_UNREAD_ICON)
    });
  });
});
