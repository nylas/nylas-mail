import _ from 'underscore'
import Message from './message'
import Contact from './contact'
import Category from './category'
import Attributes from '../attributes'
import DatabaseStore from '../stores/database-store'
import ModelWithMetadata from './model-with-metadata'


/**
  Public: The Thread model represents a Thread object served by the Nylas Platform API.
  For more information about Threads on the Nylas Platform, read the
  [Threads API Documentation](https://nylas.com/docs/api#threads)

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
    'snippet': Attributes.String({
      modelKey: 'snippet',
    }),

    'subject': Attributes.String({
      queryable: true,
      modelKey: 'subject',
    }),

    'unread': Attributes.Boolean({
      queryable: true,
      modelKey: 'unread',
    }),

    'starred': Attributes.Boolean({
      queryable: true,
      modelKey: 'starred',
    }),

    'version': Attributes.Number({
      queryable: true,
      modelKey: 'version',
    }),

    'categories': Attributes.Collection({
      queryable: true,
      modelKey: 'categories',
      itemClass: Category,
    }),

    'categoriesType': Attributes.String({
      modelKey: 'categoriesType',
    }),

    'participants': Attributes.Collection({
      queryable: true,
      joinOnField: 'email',
      modelKey: 'participants',
      itemClass: Contact,
    }),

    'hasAttachments': Attributes.Boolean({
      modelKey: 'has_attachments',
    }),

    'lastMessageReceivedTimestamp': Attributes.DateTime({
      queryable: true,
      modelKey: 'lastMessageReceivedTimestamp',
      jsonKey: 'last_message_received_timestamp',
    }),

    'lastMessageSentTimestamp': Attributes.DateTime({
      queryable: true,
      modelKey: 'lastMessageSentTimestamp',
      jsonKey: 'last_message_sent_timestamp',
    }),

    'inAllMail': Attributes.Boolean({
      queryable: true,
      modelKey: 'inAllMail',
      jsonKey: 'in_all_mail',
    }),
  })

  static naturalSortOrder = () => {
    return Thread.attributes.lastMessageReceivedTimestamp.descending()
  }

  static additionalSQLiteConfig = {
    setup: () => [
      'CREATE TABLE IF NOT EXISTS `ThreadCounts` (`category_id` TEXT PRIMARY KEY, `unread` INTEGER, `total` INTEGER)',
      'CREATE UNIQUE INDEX IF NOT EXISTS ThreadCountsIndex ON `ThreadCounts` (category_id DESC)',
      'CREATE INDEX IF NOT EXISTS ThreadListIndex ON Thread(last_message_received_timestamp DESC, id)',
      'CREATE INDEX IF NOT EXISTS ThreadListSentIndex ON Thread(last_message_sent_timestamp DESC, id)',
      'CREATE INDEX IF NOT EXISTS ThreadStarIndex ON Thread(account_id, starred)',
    ],
  }

  static searchable = true

  static searchFields = ['subject', 'participants', 'body']

  messages() {
    return (
      DatabaseStore.findAll(Message)
      .where({threadId: this.id})
      .include(Message.attributes.body)
    )
  }

  get labels() {
    return this.categories;
  }

  set labels(labels) {
    this.categories = labels;
  }

  get folders() {
    return this.categories;
  }

  set folders(folders) {
    this.categories = folders;
  }

  get inAllMail() {
    if (this.categoriesType === 'labels') {
      const inAllMail = _.any(this.categories, cat => cat.name === 'all')
      if (inAllMail) {
        return true;
      }
      const inTrashOrSpam = _.any(this.categories, cat => cat.name === 'trash' || cat.name === 'spam')
      if (!inTrashOrSpam) {
        return true;
      }
      return false
    }
    return true
  }

  fromJSON(json) {
    super.fromJSON(json)

    if (json.folders) {
      this.categoriesType = 'folders'
      this.categories = Thread.attributes.categories.fromJSON(json.folders)
    }

    if (json.labels) {
      this.categoriesType = 'labels'
      this.categories = Thread.attributes.categories.fromJSON(json.labels)
    }

    ['participants', 'categories'].forEach((attr) => {
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

Object.defineProperty(Thread.attributes, "labels", {
  enumerable: false,
  get: () => Thread.attributes.categories,
})

Object.defineProperty(Thread.attributes, "folders", {
  enumerable: false,
  get: () => Thread.attributes.categories,
})

export default Thread
