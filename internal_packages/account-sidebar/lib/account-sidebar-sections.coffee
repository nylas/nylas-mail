{Actions, SyncbackCategoryTask, DestroyCategoryTask} = require 'nylas-exports'

class AccountSidebarSection

  constructor: ({@title, @iconName, @items} = {}) ->


class CategorySidebarSection extends AccountSidebarSection

  constructor: ({@title, @iconName, @account, @items} = {}) ->

  onCreateItem: (displayName) =>
    return unless @account
    CategoryClass = @account.categoryClass()
    category = new CategoryClass
      displayName: displayName
      accountId: @account.id
    Actions.queueTask(new SyncbackCategoryTask({category}))

module.exports = {
  AccountSidebarSection
  CategorySidebarSection
}
