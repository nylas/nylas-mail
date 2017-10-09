/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */
import path from 'path';
import fs from 'fs-plus';
import { ipcRenderer } from 'electron';
import { Disposable } from 'event-kit';
import Utils from './flux/models/utils';

import MenuHelpers from './menu-helpers';

export default class MenuManager {
  constructor({ resourcePath }) {
    this.resourcePath = resourcePath;
    this.template = [];
    this.loadPlatformItems();

    AppEnv.keymaps.onDidReloadKeymap(() => this.update());
    AppEnv.commands.onRegistedCommandsChanged(() => this.update());
  }

  // Public: Adds the given items to the application menu.
  //
  // ## Examples
  //
  // ```coffee
  //   AppEnv.menu.add [
  //     {
  //       label: 'Hello'
  //       submenu : [{label: 'World!', command: 'hello:world'}]
  //     }
  //   ]
  // ```
  //
  // * `items` An {Array} of menu item {Object}s containing the keys:
  //   * `label` The {String} menu label.
  //   * `submenu` An optional {Array} of sub menu items.
  //   * `command` An optional {String} command to trigger when the item is
  //     clicked.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to remove the
  // added menu items.
  add(items) {
    const cloned = Utils.deepClone(items);
    for (const item of cloned) {
      this.merge(this.template, item);
    }
    this.update();

    return new Disposable(() => this.remove(items));
  }

  remove(items) {
    for (const item of items) {
      this.unmerge(this.template, item);
    }
    return this.update();
  }

  // Public: Refreshes the currently visible menu.
  update = () => {
    if (this.pendingUpdateOperation) {
      return;
    }
    this.pendingUpdateOperation = true;
    window.requestAnimationFrame(() => {
      this.pendingUpdateOperation = false;
      MenuHelpers.forEachMenuItem(this.template, item => {
        if (item.command && item.command.startsWith('application:') === false) {
          item.enabled = AppEnv.commands.listenerCountForCommand(item.command) > 0;
        }
        if (item.submenu != null) {
          item.enabled = !item.submenu.every(subitem => subitem.enabled === false);
        }
        if (item.hideWhenDisabled) {
          item.visible = item.enabled;
        }
      });
      return this.sendToBrowserProcess(this.template, AppEnv.keymaps.getBindingsForAllCommands());
    });
  };

  loadPlatformItems() {
    const menusDirPath = path.join(this.resourcePath, 'menus');
    const platformMenuPath = fs.resolve(menusDirPath, process.platform, ['json']);
    const { menu } = require(platformMenuPath);
    return this.add(menu);
  }

  // Merges an item in a submenu aware way such that new items are always
  // appended to the bottom of existing menus where possible.
  merge(menu, item) {
    return MenuHelpers.merge(menu, item);
  }

  unmerge(menu, item) {
    return MenuHelpers.unmerge(menu, item);
  }

  // OSX can't handle displaying accelerators for multiple keystrokes.
  // If they are sent across, it will stop processing accelerators for the rest
  // of the menu items.
  filterMultipleKeystroke(keystrokesByCommand) {
    if (!keystrokesByCommand) {
      return {};
    }
    const filtered = {};

    for (const key of Object.keys(keystrokesByCommand)) {
      const bindings = keystrokesByCommand[key];
      for (const binding of bindings) {
        if (binding.includes(' ')) {
          continue;
        }
        if (!/(command|ctrl|shift|alt|mod)/.test(binding) && !/f\d+/.test(binding)) {
          continue;
        }
        if (!filtered[key]) {
          filtered[key] = [];
        }
        filtered[key].push(binding);
      }
    }

    return filtered;
  }

  sendToBrowserProcess(template, keystrokesByCommand) {
    const filtered = this.filterMultipleKeystroke(keystrokesByCommand);
    return ipcRenderer.send('update-application-menu', template, filtered);
  }
}
