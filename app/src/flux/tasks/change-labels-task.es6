import Label from '../models/label';
import ChangeMailTask from './change-mail-task';
import Attributes from '../attributes';

// Public: Create a new task to apply labels to a message or thread.
//
// Takes an options object of the form:
// - labelsToAdd: An {Array} of {Category}s or {Category} ids to add
// - labelsToRemove: An {Array} of {Category}s or {Category} ids to remove
// - threads: An {Array} of {Thread}s or {Thread} ids
// - messages: An {Array} of {Message}s or {Message} ids
//
export default class ChangeLabelsTask extends ChangeMailTask {
  static attributes = Object.assign({}, ChangeMailTask.attributes, {
    labelsToAdd: Attributes.Collection({
      modelKey: 'labelsToAdd',
      itemClass: Label,
    }),
    labelsToRemove: Attributes.Collection({
      modelKey: 'labelsToRemove',
      itemClass: Label,
    }),
  });

  label() {
    return 'Applying labels';
  }

  description() {
    if (this.taskDescription) {
      return this.taskDescription;
    }

    let countString = '';
    if (this.threadIds.length > 1) {
      countString = ` ${this.threadIds.length} threads`;
    }

    const removed = this.labelsToRemove[0];
    const added = this.labelsToAdd[0];

    // Spam / trash interactions are always "moves" because they're the three
    // folders of Gmail. If another folder is involved, we need to decide to
    // return either "Moved to Bla" or "Added Bla".
    if (added && added.name === 'spam') {
      return `Marked${countString} as Spam`;
    } else if (removed && removed.name === 'spam') {
      return `Unmarked${countString} as Spam`;
    } else if (added && added.name === 'trash') {
      return `Trashed${countString}`;
    } else if (removed && removed.name === 'trash') {
      return `Removed${countString} from Trash`;
    }
    if (this.labelsToAdd.length === 0 && this.labelsToRemove.find(l => l.role === 'inbox')) {
      return `Archived${countString}`;
    } else if (this.labelsToRemove.length === 0 && this.labelsToAdd.find(l => l.role === 'inbox')) {
      return `Unarchived${countString}`;
    }
    if (this.labelsToAdd.length === 1 && this.labelsToRemove.length === 0) {
      return `Added ${added.displayName}${countString ? ' to' : ''}${countString}`;
    }
    if (this.labelsToAdd.length === 0 && this.labelsToRemove.length === 1) {
      return `Removed ${removed.displayName}${countString ? ' from' : ''}${countString}`;
    }
    return `Changed labels${countString ? ' on' : ''}${countString}`;
  }

  _isArchive() {
    const toAdd = this.labelsToAdd.map(l => l.name);
    return toAdd.includes('all') || toAdd.includes('archive');
  }

  validate() {
    if (this.messageIds.length) {
      throw new Error('ChangeLabelsTask: Changing individual message labels is unsupported');
    }
    if (!this.labelsToAdd) {
      throw new Error(`Assertion Failure: ChangeLabelsTask requires labelsToAdd`);
    }
    if (!this.labelsToRemove) {
      throw new Error(`Assertion Failure: ChangeLabelsTask requires labelsToRemove`);
    }
    for (const l of [].concat(this.labelsToAdd, this.labelsToRemove)) {
      if (l instanceof Label === false) {
        throw new Error(
          `Assertion Failure: ChangeLabelsTask received a non-label: ${JSON.stringify(l)}`
        );
      }
    }
    super.validate();
  }

  createUndoTask() {
    const task = super.createUndoTask();
    const { labelsToAdd, labelsToRemove } = task;
    task.labelsToAdd = labelsToRemove;
    task.labelsToRemove = labelsToAdd;
    return task;
  }
}
