import { ComponentRegistry } from 'mailspring-exports';
import { activate, deactivate } from '../lib/main';

import MyMessageSidebar from '../lib/my-message-sidebar';
import MyComposerButton from '../lib/my-composer-button';

describe('activate', () => {
  it('should register the composer button and sidebar', () => {
    spyOn(ComponentRegistry, 'register');
    activate();
    expect(ComponentRegistry.register).toHaveBeenCalledWith(MyComposerButton, {
      role: 'Composer:ActionButton',
    });
    expect(ComponentRegistry.register).toHaveBeenCalledWith(MyMessageSidebar, {
      role: 'MessageListSidebar:ContactCard',
    });
  });
});

describe('deactivate', () => {
  it('should unregister the composer button and sidebar', () => {
    spyOn(ComponentRegistry, 'unregister');
    deactivate();
    expect(ComponentRegistry.unregister).toHaveBeenCalledWith(MyComposerButton);
    expect(ComponentRegistry.unregister).toHaveBeenCalledWith(MyMessageSidebar);
  });
});
