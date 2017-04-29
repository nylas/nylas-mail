import _ from 'underscore';
import Thread from '../models/thread';
import Message from '../models/message';
import Category from '../models/category';
import DatabaseStore from '../stores/database-store';
import CategoryStore from '../stores/category-store';
import AccountStore from '../stores/account-store';
import ChangeMailTask from './change-mail-task';
import SyncbackCategoryTask from './syncback-category-task';

// Public: Create a new task to apply labels to a message or thread.
//
// Takes an options object of the form:
// - labelsToAdd: An {Array} of {Category}s or {Category} ids to add
// - labelsToRemove: An {Array} of {Category}s or {Category} ids to remove
// - threads: An {Array} of {Thread}s or {Thread} ids
// - messages: An {Array} of {Message}s or {Message} ids
export default class ChangeLabelsTask extends ChangeMailTask {

  constructor(options = {}) {
    super(options);
    this.source = options.source
    this.labelsToAdd = options.labelsToAdd || [];
    this.labelsToRemove = options.labelsToRemove || [];
    this.taskDescription = options.taskDescription;
  }

  label() {
    return "Applying labels";
  }

  categoriesToAdd() {
    return this.labelsToAdd;
  }

  categoriesToRemove() {
    return this.labelsToRemove;
  }

  description() {
    if (this.taskDescription) {
      return this.taskDescription;
    }

    let countString = "";
    if (this.threads.length > 1) {
      countString = ` ${this.threads.length} threads`;
    }

    const removed = this.labelsToRemove[0];
    const added = this.labelsToAdd[0];
    const objectsAvailable = (added || removed) instanceof Category;

    // Note: In the future, we could move this logic to the task
    // factory and pass the string in as this.taskDescription (ala Snooze), but
    // it's nice to have them declaratively based on the actual labels.
    if (objectsAvailable) {
      const looksLikeMove = (this.labelsToAdd.length === 1 && this.labelsToRemove.length > 0);

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
      if (looksLikeMove) {
        if (added.name === 'all') {
          return `Archived${countString}`;
        } else if (removed.name === 'all') {
          return `Unarchived${countString}`;
        }
        return `Moved${countString} to ${added.displayName}`;
      }
      if (this.labelsToAdd.length === 1 && this.labelsToRemove.length === 0) {
        return `Added ${added.displayName}${countString ? ' to' : ''}${countString}`;
      }
      if (this.labelsToAdd.length === 0 && this.labelsToRemove.length === 1) {
        return `Removed ${removed.displayName}${countString ? ' from' : ''}${countString}`;
      }
    }
    return `Changed labels${countString ? ' on' : ''}${countString}`;
  }

  isDependentOnTask(other) {
    return super.isDependentOnTask(other) || (other instanceof SyncbackCategoryTask);
  }

  // In Gmail all threads /must/ belong to either All Mail, Trash and Spam, and
  // they are mutually exclusive, so we need to make sure that any add/remove
  // label operation still guarantees that constraint
  _ensureAndUpdateLabels(account, existingLabelsToAdd, existingLabelsToRemove = {}) {
    const labelsToAdd = existingLabelsToAdd;
    let labelsToRemove = existingLabelsToRemove;

    const setToAdd = new Set(_.compact(_.pluck(labelsToAdd, 'name')));
    const setToRemove = new Set(_.compact(_.pluck(labelsToRemove, 'name')));

    if (setToRemove.has('all')) {
      if (!setToAdd.has('spam') && !setToAdd.has('trash')) {
        labelsToRemove = _.reject(labelsToRemove, label => label.name === 'all');
      }
    } else if (setToAdd.has('all')) {
      if (!setToRemove.has('trash')) {
        labelsToRemove.push(CategoryStore.getTrashCategory(account));
      }
      if (!setToRemove.has('spam')) {
        labelsToRemove.push(CategoryStore.getSpamCategory(account));
      }
    }

    if (setToRemove.has('trash')) {
      if (!setToAdd.has('spam') && !setToAdd.has('all')) {
        labelsToAdd.push(CategoryStore.getAllMailCategory(account));
      }
    } else if (setToAdd.has('trash')) {
      if (!setToRemove.has('all')) {
        labelsToRemove.push(CategoryStore.getAllMailCategory(account))
      }
      if (!setToRemove.has('spam')) {
        labelsToRemove.push(CategoryStore.getSpamCategory(account))
      }
    }

    if (setToRemove.has('spam')) {
      if (!setToAdd.has('trash') && !setToAdd.has('all')) {
        labelsToAdd.push(CategoryStore.getAllMailCategory(account));
      }
    } else if (setToAdd.has('spam')) {
      if (!setToRemove.has('all')) {
        labelsToRemove.push(CategoryStore.getAllMailCategory(account))
      }
      if (!setToRemove.has('trash')) {
        labelsToRemove.push(CategoryStore.getTrashCategory(account))
      }
    }

    // This should technically not be possible, but we like to keep it safe
    return {
      labelsToAdd: _.compact(labelsToAdd),
      labelsToRemove: _.compact(labelsToRemove),
    };
  }

  performLocal() {
    if (this.messages.length > 0) {
      return Promise.reject(new Error("ChangeLabelsTask: N1 does not support viewing or changing labels on individual messages."))
    }
    if (this.labelsToAdd.length === 0 && this.labelsToRemove.length === 0) {
      return Promise.reject(new Error("ChangeLabelsTask: Must specify `labelsToAdd` or `labelsToRemove`"))
    }
    if (this.threads.length > 0 && this.messages.length > 0) {
      return Promise.reject(new Error("ChangeLabelsTask: You can move `threads` or `messages` but not both"))
    }
    if (this.threads.length === 0 && this.messages.length === 0) {
      return Promise.reject(new Error("ChangeLabelsTask: You must provide a `threads` or `messages` Array of models or IDs."))
    }

    return super.performLocal();
  }

  _isArchive() {
    const toAdd = this.labelsToAdd.map(l => l.name)
    return toAdd.includes("all") || toAdd.includes("archive")
  }

  recordUserEvent() {
    if (this.source === "Mail Rules") {
      return
    }
    // Actions.recordUserEvent("Threads Changed Labels", {
    //   source: this.source,
    //   isArchive: this._isArchive(),
    //   labelTypesToAdd: this.labelsToAdd.map(l => l.name || "custom"),
    //   labelTypesToRemove: this.labelsToRemove.map(l => l.name || "custom"),
    //   labelDisplayNamesToAdd: this.labelsToAdd.map(l => l.displayName),
    //   labelDisplayNamesToRemove: this.labelsToRemove.map(l => l.displayName),
    //   numThreads: this.threads.length,
    //   numMessages: this.messages.length,
    //   description: this.description(),
    //   isUndo: this._isUndoTask,
    // })
  }

  retrieveModels() {
    // Convert arrays of IDs or models to models.
    // modelify returns immediately if (no work is required)
    return Promise.props({
      labelsToAdd: DatabaseStore.modelify(Category, this.labelsToAdd),
      labelsToRemove: DatabaseStore.modelify(Category, this.labelsToRemove),
      threads: DatabaseStore.modelify(Thread, this.threads),
      messages: DatabaseStore.modelify(Message, this.messages),

    }).then(({labelsToAdd, labelsToRemove, threads, messages}) => {
      if (_.any([].concat(labelsToAdd, labelsToRemove), _.isUndefined)) {
        return Promise.reject(new Error("One or more of the specified labels could not be found."))
      }
      const account = AccountStore.accountForItems(threads);
      if (!account) {
        return Promise.reject(new Error("ChangeLabelsTask: You must provide a set of `threads` from the same Account"))
      }
      // In Gmail all threads /must/ belong to either All Mail, Trash and Spam, and
      // they are mutually exclusive, so we need to make sure that any add/remove
      // label operation still guarantees that constraint
      const updated = this._ensureAndUpdateLabels(account, labelsToAdd, labelsToRemove)

      // Remove any objects we weren't able to find. This can happen pretty easily
      // if (you undo an action && other things have happened.)
      this.labelsToAdd = updated.labelsToAdd;
      this.labelsToRemove = updated.labelsToRemove;
      this.threads = _.compact(threads);
      this.messages = _.compact(messages);

      // The base class does the heavy lifting and calls changesToModel
      return Promise.resolve();
    });
  }

  processNestedMessages() {
    return false;
  }

  changesToModel(model) {
    const labelsToRemoveIds = _.pluck(this.labelsToRemove, 'id')

    let labels = _.reject(model.labels, ({id}) => labelsToRemoveIds.includes(id));
    labels = labels.concat(this.labelsToAdd);
    labels = _.uniq(labels, false, label => label.id);
    return {labels};
  }

  requestBodyForModel(model) {
    const folder = model.labels.find(l => l.object === 'folder')
    const labels = model.labels.filter(l => l.object === 'label')

    if (folder) {
      return {
        folder: folder.id,
        labels: labels.map(l => l.id),
      }
    }
    return {labels};
  }
}
