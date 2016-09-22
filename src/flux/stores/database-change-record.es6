import Utils from '../models/utils';

/*
DatabaseChangeRecord is the object emitted from the DatabaseStore when it triggers.
The DatabaseChangeRecord contains information about what type of model changed,
and references to the new model values. All mutations to the database produce these
change records.
*/
export default class DatabaseChangeRecord {

  constructor(options) {
    this.options = options;

    // When DatabaseChangeRecords are sent over IPC to other windows, their object
    // payload is sub-serialized into a JSON string. This means that we can wait
    // to deserialize models until someone in the window asks for `change.objects`
    this._objects = options.objects;
    this._objectsString = options.objectsString;

    Object.defineProperty(this, 'type', {
      get: () => options.type,
    })
    Object.defineProperty(this, 'objectClass', {
      get: () => options.objectClass,
    })
    Object.defineProperty(this, 'objects', {
      get: () => {
        this._objects = this._objects || JSON.parse(this._objectsString, Utils.registeredObjectReviver);
        return this._objects;
      },
    })
  }

  toJSON() {
    this._objectsString = this._objectsString || JSON.stringify(this._objects, Utils.registeredObjectReplacer);
    return {
      type: this.type,
      objectClass: this.objectClass,
      objectsString: this._objectsString,
    };
  }
}
