import _ from 'underscore';
import {Listener, Publisher} from '../flux/modules/reflux-coffee';
import {includeModule} from '../flux/coffee-helpers';

export class Registry {

  static include = includeModule;

  constructor(name) {
    this.name = name;
    this.clear();
  }

  register(extension, {priority = 0} = {}) {
    this.validateExtension(extension, 'register');

    if (this._registry.find(entry => entry.name === extension.name)) {
      throw new Error(`ExtensionRegistry.${this.name}.register requires each extension to have a unique name.`);
    }

    this._registry.push({name: extension.name, extension, priority});
    this._registry.sort((a, b) => a.priority < b.priority);
    this.triggerDebounced();
    return this;
  }

  unregister(extension) {
    this.validateExtension(extension, 'unregister');
    this._registry = this._registry.filter(entry => entry.extension !== extension);
    this.triggerDebounced();
  }

  extensions() {
    return this._registry.map(e => e.extension);
  }

  clear() {
    this._registry = [];
  }

  triggerDebounced = _.debounce(() => this.trigger(), 1);

  validateExtension(extension, method) {
    if (!extension || Array.isArray(extension) || !_.isObject(extension)) {
      throw new Error(`ExtensionRegistry.${this.name}.${method} requires a valid extension object that implements one of the functions defined by ${this.name}Extension`);
    }
    if (!extension.name) {
      throw new Error(`ExtensionRegistry.${this.name}.${method} requires a \`name\` property defined on the extension object`);
    }
  }
}

Registry.include(Publisher);
Registry.include(Listener);

export const Composer = new Registry('Composer');

export const MessageView = new Registry('MessageView');

export const ThreadList = new Registry('ThreadList');

export const AccountSidebar = new Registry('AccountSidebar');
