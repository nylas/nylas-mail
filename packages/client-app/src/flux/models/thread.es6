import _ from 'underscore'
import Message from './message'
import Contact from './contact'
import Folder from './folder'
import Label from './label'
import Category from './category'
import Attributes from '../attributes'
import DatabaseStore from '../stores/database-store'
import ModelWithMetadata from './model-with-metadata'


/*
Public: The Thread model represents a Thread object served by the Nylas Platform API.
For more information about Threads on the Nylas Platform, read the
[Threads API Documentation](https://nylas.com/cloud/docs#threads)

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
class Thread extends ModelWithMetadata {

  static attributes = _.extend({}, ModelWithMetadata.attributes, {
    snippet: Attributes.String({
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
      modelKey: 'version',
    }),

    categories: Attributes.Collection({
      queryable: true,
      modelKey: 'categories',
      joinOnField: 'id',
      joinQueryableBy: ['inAllMail', 'lastMessageReceivedTimestamp', 'lastMessageSentTimestamp', 'unread'],
      itemClass: Category,
    }),

    folders: Attributes.Collection({
      modelKey: 'folders',
      itemClass: Folder,
    }),

    labels: Attributes.Collection({
      modelKey: 'labels',
      joinOnField: 'id',
      joinQueryableBy: ['inAllMail', 'lastMessageReceivedTimestamp', 'lastMessageSentTimestamp', 'unread'],
      itemClass: Label,
    }),

    participants: Attributes.Collection({
      queryable: true,
      modelKey: 'participants',
      joinOnField: 'email',
      joinQueryableBy: ['lastMessageReceivedTimestamp'],
      itemClass: Contact,
    }),

    hasAttachments: Attributes.Boolean({
      modelKey: 'hasAttachments',
    }),

    lastMessageReceivedTimestamp: Attributes.DateTime({
      queryable: true,
      modelKey: 'lastMessageReceivedTimestamp',
    }),

    lastMessageSentTimestamp: Attributes.DateTime({
      queryable: true,
      modelKey: 'lastMessageSentTimestamp',
    }),

    inAllMail: Attributes.Boolean({
      queryable: true,
      modelKey: 'inAllMail',
    }),

    isSearchIndexed: Attributes.Boolean({
      queryable: true,
      modelKey: 'isSearchIndexed',
      defaultValue: false,
      loadFromColumn: true,
    }),

    // This corresponds to the rowid in the FTS table. We need to use the FTS
    // rowid when updating and deleting items in the FTS table because otherwise
    // these operations would be way too slow on large FTS tables.
    searchIndexId: Attributes.Number({
      modelKey: 'searchIndexId',
    }),
  })

  static sortOrderAttribute = () => {
    return Thread.attributes.lastMessageReceivedTimestamp
  }

  static naturalSortOrder = () => {
    return Thread.sortOrderAttribute().descending()
  }

  static additionalSQLiteConfig = {
    setup: () => [
      // ThreadCounts
      'CREATE TABLE IF NOT EXISTS `ThreadCounts` (`category_id` TEXT PRIMARY KEY, `unread` INTEGER, `total` INTEGER)',
      'CREATE UNIQUE INDEX IF NOT EXISTS ThreadCountsIndex ON `ThreadCounts` (category_id DESC)',

      // ThreadContact
      'CREATE INDEX IF NOT EXISTS ThreadContactDateIndex ON `ThreadContact` (lastMessageReceivedTimestamp DESC, value, id)',

      // ThreadCategory
      'CREATE INDEX IF NOT EXISTS ThreadListCategoryIndex ON `ThreadCategory` (lastMessageReceivedTimestamp DESC, value, inAllMail, unread, id)',
      'CREATE INDEX IF NOT EXISTS ThreadListCategorySentIndex ON `ThreadCategory` (lastMessageSentTimestamp DESC, value, inAllMail, unread, id)',

      // Thread: General index
      'CREATE INDEX IF NOT EXISTS ThreadDateIndex ON `Thread` (lastMessageReceivedTimestamp DESC)',
      'CREATE INDEX IF NOT EXISTS ThreadClientIdIndex ON `Thread` (id)',

      // Thread: Partial indexes for specific views
      'CREATE INDEX IF NOT EXISTS ThreadUnreadIndex ON `Thread` (accountId, lastMessageReceivedTimestamp DESC) WHERE unread = 1 AND inAllMail = 1',
      'CREATE INDEX IF NOT EXISTS ThreadUnifiedUnreadIndex ON `Thread` (lastMessageReceivedTimestamp DESC) WHERE unread = 1 AND inAllMail = 1',

      'DROP INDEX IF EXISTS `Thread`.ThreadStarIndex',
      'CREATE INDEX IF NOT EXISTS ThreadStarredIndex ON `Thread` (accountId, lastMessageReceivedTimestamp DESC) WHERE starred = 1 AND inAllMail = 1',
      'CREATE INDEX IF NOT EXISTS ThreadUnifiedStarredIndex ON `Thread` (lastMessageReceivedTimestamp DESC) WHERE starred = 1 AND inAllMail = 1',

      'CREATE INDEX IF NOT EXISTS ThreadIsSearchIndexedIndex ON `Thread` (isSearchIndexed, id)',
      'CREATE INDEX IF NOT EXISTS ThreadIsSearchIndexedLastMessageReceivedIndex ON `Thread` (isSearchIndexed, lastMessageReceivedTimestamp)',
    ],
  }

  static searchable = true

  static searchFields = ['subject', 'to_', 'from_', 'categories', 'body']

  async messages({includeHidden} = {}) {
    const messages = await DatabaseStore.findAll(Message)
      .where({threadId: this.id})
      .include(Message.attributes.body)
    if (!includeHidden) {
      return messages.filter(message => !message.isHidden())
    }
    return messages
  }

  /** Computes the plaintext version of ALL messages.
   * WARNING: This method is VERY expensive.
   * Parsing a thread with ~50 messages took ~2-3 seconds!
   */
  computePlainText() {
    return Promise.map(this.messages(), (message) => {
      return new Promise((resolve) => {
        // Add a defer tick so we don't COMPLETELY hang the thread.
        setTimeout(() => {
          resolve(`${message.replyAttributionLine()}\n\n${message.computePlainText()}`)
        }, 1)
      })
    }).then((plainTextBodies = []) => {
      const msgDivider = "\n\n--------------------------------------------------\n"
      return plainTextBodies.join(msgDivider)
    })
  }

  get categories() {
    return [].concat(this.folders, this.labels);
  }

  /**
   * In the `clone` case, there are `categories` set, but no `folders` nor
   * `labels`
   *
   * When loading data from the API, there are `folders` AND `labels` but
   * no `categories` yet.
   */
  fromJSON(json) {
    super.fromJSON(json)

    ['participants'].forEach((attr) => {
      const value = this[attr]
      if (!(value && value instanceof Array)) {
        return;
      }
      value.forEach((item) => {
        item.accountId = this.accountId
      })
    })

    return this
  }

  /**
  * Public: Returns true if the thread has a {Category} with the given
  * name. Note, only catgories of type `Category.Types.Standard` have valid
  * `names`
  * - `id` A {String} {Category} name
  */
  categoryNamed(name) {
    return _.findWhere(this.categories, {name})
  }

  sortedCategories() {
    if (!this.categories) {
      return []
    }
    let out = []
    const isImportant = (l) => l.name === 'important'
    const isStandardCategory = (l) => l.isStandardCategory()
    const isUnhiddenStandardLabel = (l) => (
      !isImportant(l) &&
      isStandardCategory(l) &&
      !(l.isHiddenCategory())
    )

    const importantLabel = _.find(this.categories, isImportant)
    if (importantLabel) {
      out = out.concat(importantLabel)
    }

    const standardLabels = _.filter(this.categories, isUnhiddenStandardLabel)
    if (standardLabels.length > 0) {
      out = out.concat(standardLabels)
    }

    const userLabels = _.filter(this.categories, (l) => (
      !isImportant(l) && !isStandardCategory(l)
    ))
    if (userLabels.length > 0) {
      out = out.concat(_.sortBy(userLabels, 'displayName'))
    }
    return out
  }
}

export default Thread;
