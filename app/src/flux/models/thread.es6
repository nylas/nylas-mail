import Message from './message';
import Contact from './contact';
import Folder from './folder';
import Label from './label';
import Category from './category';
import Attributes from '../attributes';
import DatabaseStore from '../stores/database-store';
import ModelWithMetadata from './model-with-metadata';

/*
Public: The Thread model represents an email thread.

Attributes

`snippet`: {AttributeString} A short, ~140 character string with the content
  of the last message in the thread. Queryable.

`subject`: {AttributeString} The subject of the thread. Queryable.

`unread`: {AttributeBoolean} True if the thread is unread. Queryable.

`starred`: {AttributeBoolean} True if the thread is starred. Queryable.

`version`: {AttributeNumber} The version number of the thread.

`participants`: {AttributeCollection} A set of {Contact} models
  representing the participants in the thread.
  Note: Contacts on Threads do not have IDs.

`lastMessageReceivedTimestamp`: {AttributeDateTime} The timestamp of the
  last message on the thread.

This class also inherits attributes from {Model}

Section: Models
@class Thread
*/
export default class Thread extends ModelWithMetadata {
  static attributes = Object.assign({}, ModelWithMetadata.attributes, {
    snippet: Attributes.String({
      // TODO NONFUNCTIONAL
      modelKey: 'snippet',
    }),

    subject: Attributes.String({
      queryable: true,
      modelKey: 'subject',
    }),

    unread: Attributes.Boolean({
      queryable: true,
      modelKey: 'unread',
    }),

    starred: Attributes.Boolean({
      queryable: true,
      modelKey: 'starred',
    }),

    version: Attributes.Number({
      queryable: true,
      jsonKey: 'v',
      modelKey: 'version',
    }),

    categories: Attributes.Collection({
      queryable: true,
      modelKey: 'categories',
      joinOnField: 'id',
      joinQueryableBy: [
        'inAllMail',
        'lastMessageReceivedTimestamp',
        'lastMessageSentTimestamp',
        'unread',
      ],
      itemClass: Category,
    }),

    folders: Attributes.Collection({
      modelKey: 'folders',
      itemClass: Folder,
    }),

    labels: Attributes.Collection({
      modelKey: 'labels',
      joinOnField: 'id',
      joinQueryableBy: [
        'inAllMail',
        'lastMessageReceivedTimestamp',
        'lastMessageSentTimestamp',
        'unread',
      ],
      itemClass: Label,
    }),

    participants: Attributes.Collection({
      modelKey: 'participants',
      itemClass: Contact,
    }),

    attachmentCount: Attributes.Number({
      modelKey: 'attachmentCount',
    }),

    lastMessageReceivedTimestamp: Attributes.DateTime({
      queryable: true,
      jsonKey: 'lmrt',
      modelKey: 'lastMessageReceivedTimestamp',
    }),

    lastMessageSentTimestamp: Attributes.DateTime({
      queryable: true,
      jsonKey: 'lmst',
      modelKey: 'lastMessageSentTimestamp',
    }),

    inAllMail: Attributes.Boolean({
      queryable: true,
      modelKey: 'inAllMail',
    }),
  });

  static sortOrderAttribute = () => {
    return Thread.attributes.lastMessageReceivedTimestamp;
  };

  static naturalSortOrder = () => {
    return Thread.sortOrderAttribute().descending();
  };

  async messages({ includeHidden } = {}) {
    const messages = await DatabaseStore.findAll(Message)
      .where({ threadId: this.id })
      .include(Message.attributes.body);
    if (!includeHidden) {
      return messages.filter(message => !message.isHidden());
    }
    return messages;
  }

  get categories() {
    return [].concat(this.folders || [], this.labels || []);
  }

  set categories(c) {
    // noop
  }

  /**
   * In the `clone` case, there are `categories` set, but no `folders` nor
   * `labels`
   *
   * When loading data from the API, there are `folders` AND `labels` but
   * no `categories` yet.
   */
  fromJSON(json) {
    super.fromJSON(json);

    if (this.participants && this.participants instanceof Array) {
      this.participants.forEach(item => {
        item.accountId = this.accountId;
      });
    }
    return this;
  }

  sortedCategories() {
    if (!this.categories) {
      return [];
    }
    let out = [];
    const isImportant = l => l.role === 'important';
    const isStandardCategory = l => l.isStandardCategory();
    const isUnhiddenStandardLabel = l =>
      !isImportant(l) && isStandardCategory(l) && !l.isHiddenCategory();

    const importantLabel = this.categories.find(isImportant);
    if (importantLabel) {
      out = out.concat(importantLabel);
    }

    const standardLabels = this.categories.filter(isUnhiddenStandardLabel);
    if (standardLabels.length > 0) {
      out = out.concat(standardLabels);
    }

    const userLabels = this.categories.filter(l => !isImportant(l) && !isStandardCategory(l));

    if (userLabels.length > 0) {
      out = out.concat(userLabels.sort((a, b) => a.displayName.localeCompare(b.displayName)));
    }
    return out;
  }
}
