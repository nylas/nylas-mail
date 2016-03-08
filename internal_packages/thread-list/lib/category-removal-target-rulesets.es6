import {AccountStore, CategoryStore} from 'nylas-exports';


/**
 * A RemovalTargetRuleset for categories is a map that represents the
 * target/destination Category when removing threads from another given
 * category, i.e., when removing them from their current CategoryPerspective.
 * Rulesets are of the form:
 *
 *   (categoryName) => function(accountId): Category
 *
 * Keys correspond to category names, e.g.`{'inbox', 'trash',...}`, which
 * correspond to the name of the categories associated with a perspective
 * Values are functions with the following signature:
 *
 *   `function(accountId): Category`
 *
 * If a value is null instead of a function, it means that removing threads from
 * that standard category has no effect, i.e. it is a no-op
 *
 * RemovalRulesets should also contain a special key `other`, that is meant to be used
 * when a key cannot be found for a given Category name
 *
 * @typedef {Object} - RemovalTargetRuleset
 * @property {(function|null)} target - Function that returns the target category
*/
const CategoryRemovalTargetRulesets = {

  Default: {
    // + Has no effect in Spam, Sent.
    spam: null,
    sent: null,

    // + In inbox, move to [Archive or Trash]
    inbox: (accountId)=> {
      const account = AccountStore.accountForId(accountId)
      return account.defaultFinishedCategory()
    },

    // + In all/archive, move to trash.
    all: (accountId) => CategoryStore.getTrashCategory(accountId),
    archive: (accountId) => CategoryStore.getTrashCategory(accountId),

    // TODO
    // + In trash, it should delete permanently or do nothing.
    trash: null,

    // + In label or folder, move to [Archive or Trash]
    other: (accountId)=> {
      const account = AccountStore.accountForId(accountId)
      return account.defaultFinishedCategory()
    },
  },

  Gmail: {
    // + It has no effect in Spam, Sent, All Mail/Archive
    all: null,
    spam: null,
    sent: null,
    archive: null,

    // + In inbox, move to [Archive or Trash].
    inbox: (accountId)=> {
      const account = AccountStore.accountForId(accountId)
      return account.defaultFinishedCategory()
    },

    // + In trash, move to Inbox
    trash: (accountId) => CategoryStore.getInboxCategory(accountId),

    // + In label, remove label
    // + In folder, move to archive
    other: (accountId)=> {
      const account = AccountStore.accountForId(accountId)
      if (account.usesFolders()) {
        // If we are removing threads from a folder, it means we are move the
        // threads // somewhere. In this case, to the archive
        return CategoryStore.getArchiveCategory(account)
      }
      // Otherwise, when removing a label, we don't want to move it anywhere
      return null
    },
  },
}

export default CategoryRemovalTargetRulesets
