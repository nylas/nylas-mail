import {Utils} from 'nylas-exports'

/*
There are many places we want to have a SalesforceObject for which we
don't yet have the full data.

An example is when we're created a linked SalesforceObject in a
SalesforceForm. It may take a user a long time to create that object. In
the meantime, we stub in a PendingSalesforceObject to indicate that such
an activity is in progress.
*/

export default class PendingSalesforceObject {
  constructor({id, type, name}) {
    this.id = id || Utils.generateTempId();
    this.type = type;
    this.name = name;
  }

  toJSON() {
    return {
      id: this.id,
      type: this.type,
      name: this.name,
      pendingSalesforceObject: true,
    }
  }
}
