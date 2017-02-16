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
    this._objects = options.objects
    this._objectsString = options.objectsString;
    this._objects = this._objects || JSON.parse(this._objectsString, Utils.registeredObjectReviver);

    /**
     * We notify the entire app in ALL windows when anything in the
     * database changes. This is normally okay except for Messages because
     * their bodies might contain millions of charcters that will have to
     * be serialized, sent over IPC, and deserialized in each and every
     * window! We make an exception for message bodies here to
     * dramatically reduce the processing overhead of sending object
     * changes across the deltas.
     */
    if (options.objectClass === "Message") {
      this._objects = this._objects.map((o) => {
        if (!o.draft) {
          o.body = null;
        }
        return o;
      })
    }

    Object.defineProperty(this, 'type', {
      get: () => options.type,
    })
    Object.defineProperty(this, 'objectClass', {
      get: () => options.objectClass,
    })
    Object.defineProperty(this, 'objects', {
      get: () => {
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
