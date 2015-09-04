_ = require 'underscore'

AccountStore = require './flux/stores/account-store'
CategoryStore = require './flux/stores/category-store'
Thread = require './flux/models/thread'
Actions = require './flux/actions'

# This is a class cluster. Subclasses are not for external use!
# https://developer.apple.com/library/ios/documentation/General/Conceptual/CocoaEncyclopedia/ClassClusters/ClassClusters.html

class MailViewFilter

  # Factory Methods

  @forCategory: (category) ->
    new CategoryMailViewFilter(category)

  @forStarred: ->
    new StarredMailViewFilter()

  # Instance Methods

  constructor: ->

  isEqual: (other) ->
    return false unless other and @constructor.name is other.constructor.name
    return false if other.name isnt @name

    matchers = @matchers()
    otherMatchers = other.matchers()
    return false if otherMatchers.length isnt matchers.length

    for idx in [0...matchers.length]
      if matchers[idx].value() isnt otherMatchers[idx].value()
        return false

    true

  categoryId: ->
    throw new Error("categoryId: Not implemented in base class.")

  matchers: ->
    throw new Error("matchers: Not implemented in base class.")

  canApplyToThreads: ->
    throw new Error("canApplyToThreads: Not implemented in base class.")

  applyToThreads: (threadsOrIds) ->
    throw new Error("applyToThreads: Not implemented in base class.")


class StarredMailViewFilter extends MailViewFilter
  constructor: ->
    @name = "Starred"
    @iconName = "starred.png"
    @

  matchers: ->
    [Thread.attributes.starred.equal(true)]

  categoryId: ->
    null

  canApplyToThreads: ->
    true

  applyToThreads: (threadsOrIds) ->
    ChangeStarredTask = require './flux/tasks/change-starred-task'
    task = new ChangeStarredTask({threads:threadsOrIds, starred: true})
    Actions.queueTask(task)


class CategoryMailViewFilter extends MailViewFilter
  constructor: (cat) ->
    @name = cat.displayName
    @category = cat

    if cat.name
      @iconName = "#{cat.name}.png"
    else if AccountStore.current().usesLabels()
      @iconName = "tag.png"
    else
      @iconName = "folder.png"

    @

  matchers: ->
    account = AccountStore.current()
    matchers = []
    if account.usesLabels()
      matchers.push Thread.attributes.labels.contains(@category.id)
    else if account.usesFolders()
      matchers.push Thread.attributes.folders.contains(@category.id)
    matchers

  categoryId: ->
    @category.id

  canApplyToThreads: ->
    not (@category.name in CategoryStore.LockedCategoryNames)

  applyToThreads: (threadsOrIds) ->
    if AccountStore.current().usesLabels()
      FocusedMailViewStore = require './flux/stores/focused-mail-view-store'
      currentLabel = FocusedMailViewStore.mailView().category
      if currentLabel and not (currentLabel in CategoryStore.LockedCategoryNames)
        labelsToRemove = [currentLabel]

      ChangeLabelsTask = require './flux/tasks/change-labels-task'
      task = new ChangeLabelsTask
        threads: threadsOrIds
        labelsToAdd: [@category]
        labelsToRemove: labelsToRemove
    else
      ChangeFolderTask = require './flux/tasks/change-folder-task'
      task = new ChangeFolderTask
        threads: threadsOrIds
        folder: @category

    Actions.queueTask(task)


module.exports = MailViewFilter
