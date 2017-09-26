import { Folder, Actions } from 'mailspring-exports';
import SidebarItem from '../lib/sidebar-item';

describe('sidebar-item', function sidebarItemSpec() {
  it('preserves nested labels on rename', () => {
    spyOn(Actions, 'queueTask');
    const categories = [new Folder({ path: 'a.b/c', accountId: window.TEST_ACCOUNT_ID })];
    AppEnv.savedState.sidebarKeysCollapsed = {};
    const item = SidebarItem.forCategories(categories);
    item.onEdited(item, 'd');

    const task = Actions.queueTask.calls[0].args[0];
    const { existingPath, path } = task;
    expect(existingPath).toBe('a.b/c');
    expect(path).toBe('a.b/d');
  });
  it('preserves labels on rename', () => {
    spyOn(Actions, 'queueTask');
    const categories = [new Folder({ path: 'a', accountId: window.TEST_ACCOUNT_ID })];
    AppEnv.savedState.sidebarKeysCollapsed = {};
    const item = SidebarItem.forCategories(categories);
    item.onEdited(item, 'b');

    const task = Actions.queueTask.calls[0].args[0];
    const { existingPath, path } = task;
    expect(existingPath).toBe('a');
    expect(path).toBe('b');
  });
});
