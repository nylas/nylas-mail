
import _ from 'underscore';
import {Listener, Publisher} from './flux/modules/reflux-coffee';
import {includeModule} from './flux/coffee-helpers';

export class Registry {

  static include = includeModule;

  constructor(name, deprecationAdapter = (ext)=> ext) {
    this.name = name;
    this._deprecationAdapter = deprecationAdapter;
    this._registry = new Map();
  }

  register(extension) {
    this.validateExtension(extension, 'register');
    this._registry.set(extension.name, this._deprecationAdapter(extension));
    this.triggerDebounced();
    return this;
  }

  unregister(extension) {
    this.validateExtension(extension, 'unregister');
    this._registry.delete(extension.name);
    this.triggerDebounced();
  }

  extensions() {
    return Array.from(this._registry.values());
  }

  clear() {
    this._registry = new Map();
  }

  triggerDebounced() {
    _.debounce(()=> this.trigger(), 1);
  }

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

export const Composer = new Registry(
  'Composer',
  require('./extensions/composer-extension-adapter')
);

export const MessageView = new Registry(
  'MessageView',
);
