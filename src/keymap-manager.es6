import fs from 'fs-plus'
import path from 'path'
import mousetrap from 'mousetrap'
import {ipcRenderer} from 'electron'
import {Emitter, Disposable} from 'event-kit'

let suspended = false
const templateConfigKey = 'core.keymapTemplate'

/*
By default, Mousetrap stops all hotkeys within text inputs. Override this to
more specifically block only hotkeys that have no modifier keys (things like
Gmail's "x", while allowing standard hotkeys.)
*/
mousetrap.prototype.stopCallback = (e, element, combo) => {
  if (suspended) {
    return true;
  }
  const withinTextInput = element.tagName === 'INPUT' || element.tagName === 'SELECT' || element.tagName === 'TEXTAREA' || element.isContentEditable
  const withinWebview = element.tagName === 'WEBVIEW';
  if (withinWebview) {
    return true;
  }
  if (withinTextInput) {
    const isPlainKey = !/(mod|command|ctrl)/.test(combo);
    const isReservedTextEditingShortcut = /(mod|command|ctrl)\+(a|x|c|v)/.test(combo);
    return isPlainKey || isReservedTextEditingShortcut;
  }
  return false;
}

class KeymapFile {
  constructor(manager, filePath) {
    this._manager = manager;
    this._path = filePath;
    this._bindings = {};
    this._disposable = null;
  }

  load = () => {
    let keymaps = null;
    try {
      keymaps = JSON.parse(fs.readFileSync(this._path))
    } catch (e) {
      if (e.code === 'ENOENT') {
        return;
      }
      console.error(e);
      return;
    }

    this._bindings = {};
    Object.keys(keymaps).forEach((command) => {
      let keystrokesArray = keymaps[command];
      if (!(keystrokesArray instanceof Array)) {
        keystrokesArray = [keystrokesArray];
      }
      for (const keystrokes of keystrokesArray) {
        this._manager.ensureKeystrokesRegistered(keystrokes);
        this._bindings[command] = this._bindings[command] || [];
        this._bindings[command].push(keystrokes);
      }
    });
    this._manager.keymapCacheInvalidated();
  }

  watch() {
    fs.watch(this._path, this.load);
  }

  bindings() {
    return this._bindings;
  }
}

export default class KeymapManager {

  constructor({configDirPath, resourcePath}) {
    this.configDirPath = configDirPath;
    this.resourcePath = resourcePath;
    this._emitter = new Emitter;
    this._registered = {};
    this._files = [];
  }

  getUserKeymapPath() {
    return path.join(this.configDirPath, 'keymap.json');
  }

  suspendAllKeymaps() {
    NylasEnv.menu.sendToBrowserProcess(NylasEnv.menu.template, {});
    suspended = true;
  }

  resumeAllKeymaps() {
    NylasEnv.menu.update();
    suspended = false;
  }

  loadKeymaps = () => {
    // Load the base keymap and the base.platform keymap
    this.loadKeymap(path.join(this.resourcePath, 'keymaps', 'base.json'))
    this.loadKeymap(path.join(this.resourcePath, 'keymaps', `base-${process.platform}.json`))

    // Load the template keymap (Gmail, Mail.app, etc.) the user has chosen
    if (this._unobserveTemplate) {
      this._unobserveTemplate.dispose();
    }
    this._unobserveTemplate = NylasEnv.config.observe(templateConfigKey, this.loadTemplateKeymap);

    const userKeymapPath = this.getUserKeymapPath()
    if (!fs.existsSync(userKeymapPath)) {
      fs.writeFileSync(userKeymapPath, "{}");
    }
    this.userKeymap = new KeymapFile(this, userKeymapPath)
    this.userKeymap.load()
    this.userKeymap.watch()
  }

  loadTemplateKeymap = () => {
    if (this._removeTemplate) {
      this._removeTemplate.dispose();
    }
    let templateFile = NylasEnv.config.get(templateConfigKey);
    if (templateFile) {
      templateFile = templateFile.replace("GoogleInbox", "Inbox by Gmail");
      const templateKeymapPath = path.join(this.resourcePath, 'keymaps', 'templates', `${templateFile}.json`);
      this._removeTemplate = this.loadKeymap(templateKeymapPath);
    }
  }

  loadKeymap(filePath) {
    const file = new KeymapFile(this, filePath);
    this._files.push(file);
    file.load();

    return new Disposable(() => {
      this._files = this._files.filter(f => f !== file);
      this.keymapCacheInvalidated();
    });
  }

  ensureKeystrokesRegistered(keystrokes) {
    if (this._registered[keystrokes]) {
      return;
    }
    this._registered[keystrokes] = true;

    mousetrap.bind(keystrokes, () => {
      for (const command of (this._commandsCache[keystrokes] || [])) {
        if (command.startsWith('application:')) {
          ipcRenderer.send('command', command);
        } else {
          NylasEnv.commands.dispatch(command);
        }
      }
      return false
    });
  }

  keymapCacheInvalidated() {
    this._bindingsCache = {};

    for (const file of this._files) {
      const fileBindings = file.bindings();
      for (const command of Object.keys(fileBindings)) {
        const keystrokesArray = fileBindings[command];
        this._bindingsCache[command] = (this._bindingsCache[command] || []).concat(keystrokesArray);
      }
    }
    if (this.userKeymap) {
      const userBindings = this.userKeymap.bindings();
      for (const command of Object.keys(userBindings)) {
        this._bindingsCache[command] = userBindings[command];
      }
    }

    this._commandsCache = {};
    for (const command of Object.keys(this._bindingsCache)) {
      for (const keystrokes of this._bindingsCache[command]) {
        if (!this._commandsCache[keystrokes]) {
          this._commandsCache[keystrokes] = [];
        }
        this._commandsCache[keystrokes].push(command);
      }
    }

    this._emitter.emit('on-did-reload-keymap');
  }

  onDidReloadKeymap = (callback) => {
    return this._emitter.on('on-did-reload-keymap', callback);
  }

  getBindingsForAllCommands() {
    return this._bindingsCache;
  }

  getBindingsForCommand(command) {
    return this._bindingsCache[command] || [];
  }
}
