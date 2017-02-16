import _ from 'underscore';
import {Listener, Publisher} from '../flux/modules/reflux-coffee';
import {includeModule} from '../flux/coffee-helpers';

export class Registry {

  static include = includeModule;

  constructor(name, deprecationAdapter = (ext) => ext) {
    this.name = name;
    this._deprecationAdapter = deprecationAdapter;
    this._registry = new Map();
  }

  register(ext, {priority = 0} = {}) {
    this.validateExtension(ext, 'register');
    const extension = this._deprecationAdapter(ext)
    this._registry.set(ext.name, {extension, priority});
    this.triggerDebounced();
    return this;
  }

  unregister(extension) {
    this.validateExtension(extension, 'unregister');
    this._registry.delete(extension.name);
    this.triggerDebounced();
  }

  extensions() {
    return _.pluck(_.sortBy(Array.from(this._registry.values()), "priority"), "extension").reverse()
  }

  clear() {
    this._registry = new Map();
  }

  triggerDebounced = _.debounce(::this.trigger, 1);

  validateExtension(extension, method) {
    if (!extension || Array.isArray(extension) || !_.isObject(extension)) {
      throw new Error(`ExtensionRegistry.${this.name}.${method} requires a valid \\
                      extension object that implements one of the functions defined by ${this.name}Extension`);
    }
    if (!extension.name) {
      throw new Error(`ExtensionRegistry.${this.name}.${method} requires a \\
                      \`name\` property defined on the extension object`);
    }
  }
}

Registry.include(Publisher);
Registry.include(Listener);

export const Composer = new Registry('Composer');

export const MessageView = new Registry('MessageView');

export const ThreadList = new Registry('ThreadList');

export const AccountSidebar = new Registry('AccountSidebar');
