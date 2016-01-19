_ = require 'underscore'
{Actions,
 SyncbackCategoryTask,
 DestroyCategoryTask,
 CategoryHelpers,
 CategoryStore,
 Category} = require 'nylas-exports'
SidebarItem = require './sidebar-item'


class SidebarSection

  @empty: (title)->
    return {
      title,
      items: []
    }

  @standardSectionForAccount: (account) ->
    cats = CategoryStore.standardCategories(account)
    items = _
      .reject(cats, (cat) -> cat.name is 'drafts')
      .map (cat) => SidebarItem.forCategories([cat])

    starredItem = SidebarItem.forStarred([account.id])
    draftsItem = SidebarItem.forDrafts(accountId: account.id)

    # Order correctly: Inbox, Starred, rest... , Drafts
    items.splice(1, 0, starredItem)
    items.push(draftsItem)

    return {
      title: 'Mailboxes'
      items: items
    }

  @standardSectionForAccounts: (accounts) ->
    return @empty('Mailboxes') if not accounts or accounts.length is 0
    return @empty('Mailboxes') if CategoryStore.categories().length is 0
    return @standardSectionForAccount(accounts[0]) if accounts.length is 1

    # TODO Decide standard items for the unified case
    inboxItem = SidebarItem.forCategories(
      (accounts.map (acc)-> CategoryStore.getStandardCategory(acc, 'inbox')),
      children: accounts.map (acc) ->
        cat = CategoryStore.getStandardCategory(acc, 'inbox')
        SidebarItem.forCategories([cat], name: acc.label)
    )
    sentItem = SidebarItem.forCategories(
      (accounts.map (acc)-> CategoryStore.getStandardCategory(acc, 'sent')),
      children: accounts.map (acc) ->
        cat = CategoryStore.getStandardCategory(acc, 'sent')
        SidebarItem.forCategories([cat], name: acc.label)
    )
    archiveItem = SidebarItem.forCategories(
      (accounts.map (acc)-> CategoryStore.getArchiveCategory(acc)),
      children: accounts.map (acc) ->
        cat = CategoryStore.getArchiveCategory(acc)
        SidebarItem.forCategories([cat], name: acc.label)
    )
    trashItem = SidebarItem.forCategories(
      (accounts.map (acc)-> CategoryStore.getTrashCategory(acc)),
      children: accounts.map (acc) ->
        cat = CategoryStore.getTrashCategory(acc)
        SidebarItem.forCategories([cat], name: acc.label)
    )
    starredItem = SidebarItem.forStarred(_.pluck(accounts, 'id'),
      children: accounts.map (acc) -> SidebarItem.forStarred([acc.id], name: acc.label)
    )
    draftsItem = SidebarItem.forDrafts(
      children: accounts.map (acc) ->
        SidebarItem.forDrafts(accountId: acc.id, name: acc.label)
    )

    items = [
      inboxItem
      starredItem
      sentItem
      archiveItem
      trashItem
      draftsItem
    ]

    return {
      title: 'Mailboxes'
      items: items
    }


  @forUserCategories: (account) ->
    return unless account
    # Compute hierarchy for user categories using known "path" separators
    # NOTE: This code uses the fact that userCategoryItems is a sorted set, eg:
    #
    # Inbox
    # Inbox.FolderA
    # Inbox.FolderA.FolderB
    # Inbox.FolderB
    #
    items = []
    seenItems = {}
    for category in CategoryStore.userCategories(account)
      # https://regex101.com/r/jK8cC2/1
      itemKey = category.displayName.replace(/[./\\]/g, '/')

      parent = null
      parentComponents = itemKey.split('/')
      for i in [parentComponents.length..1] by -1
        parentKey = parentComponents[0...i].join('/')
        parent = seenItems[parentKey]
        break if parent

      if parent
        itemDisplayName = category.displayName.substr(parentKey.length+1)
        item = SidebarItem.forCategories([category], name: itemDisplayName)
        parent.children.push(item)
      else
        item = SidebarItem.forCategories([category])
        items.push(item)
      seenItems[itemKey] = item

    return {
      title: CategoryHelpers.categoryLabel(account)
      iconName: CategoryHelpers.categoryIconName(account)
      items: items
      onCreateItem: (displayName) ->
        category = new Category
          displayName: displayName
          accountId: account.id
        Actions.queueTask(new SyncbackCategoryTask({category}))
    }


module.exports = SidebarSection
