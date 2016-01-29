_ = require 'underscore'
{Actions,
 AccountStore,
 SyncbackCategoryTask,
 DestroyCategoryTask,
 CategoryStore,
 Category} = require 'nylas-exports'
SidebarItem = require './sidebar-item'


isSectionCollapsed = (id) ->
  key = "core.accountSidebarCollapsed.#{id}Section"
  collapsed = NylasEnv.config.get(key)

toggleSectionCollapse = (section) ->
  key = "core.accountSidebarCollapsed.#{section.title}Section"
  return unless section
  NylasEnv.config.set(key, not section.collapsed)


class SidebarSection

  @empty: (title) ->
    return {
      title,
      items: []
    }

  @standardSectionForAccount: (account) ->
    if not account
      throw new Error("standardSectionForAccount: You must pass an account.")

    cats = CategoryStore.standardCategories(account)
    return @empty('Mailboxes') if cats.length is 0

    items = _
      .reject(cats, (cat) -> cat.name is 'drafts')
      .map (cat) => SidebarItem.forCategories([cat], editable: false, deletable: false)

    starredItem = SidebarItem.forStarred([account.id])
    draftsItem = SidebarItem.forDrafts([account.id])

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

    standardNames = [
      'inbox',
      'sent',
      ['archive', 'all'],
      'trash'
    ]
    items = []

    for names in standardNames
      names = if Array.isArray(names) then names else [names]
      categories = CategoryStore.getStandardCategories(accounts, names...)
      continue if categories.length is 0

      children = []
      accounts.forEach (acc) ->
        cat = _.first(_.compact(
          names.map((name) -> CategoryStore.getStandardCategory(acc, name))
        ))
        return unless cat
        children.push(SidebarItem.forCategories([cat], name: acc.label, editable: false, deletable: false))

      items.push SidebarItem.forCategories(categories, {children, editable: false, deletable: false})

    starredItem = SidebarItem.forStarred(_.pluck(accounts, 'id'),
      children: accounts.map (acc) -> SidebarItem.forStarred([acc.id], name: acc.label)
    )
    draftsItem = SidebarItem.forDrafts(_.pluck(accounts, 'id'),
      children: accounts.map (acc) -> SidebarItem.forDrafts([acc.id], name: acc.label)
    )

    # Order correctly: Inbox, Starred, rest... , Drafts
    items.splice(1, 0, starredItem)
    items.push(draftsItem)

    return {
      title: 'Mailboxes'
      items: items
    }


  @forUserCategories: (account, {title, collapsible} = {}) ->
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


    title ?= account.categoryLabel()
    collapsed = isSectionCollapsed(title)
    if collapsible
      onCollapseToggled = toggleSectionCollapse

    return {
      title: title
      iconName: account.categoryIcon()
      items: items
      collapsed: collapsed
      onCollapseToggled: onCollapseToggled
      onItemCreated: (displayName) ->
        return unless displayName
        category = new Category
          displayName: displayName
          accountId: account.id
        Actions.queueTask(new SyncbackCategoryTask({category}))
    }


module.exports = SidebarSection
