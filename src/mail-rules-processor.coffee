_ = require 'underscore'

Task = require './flux/tasks/task'
Actions = require './flux/actions'
Label = require './flux/models/label'
Folder = require './flux/models/folder'
Thread = require './flux/models/thread'
Message = require './flux/models/message'
AccountStore = require './flux/stores/account-store'
DatabaseStore = require './flux/stores/database-store'
TaskQueueStatusStore = require './flux/stores/task-queue-status-store'

MailRulesStore = require './flux/stores/mail-rules-store'
{ConditionMode, ConditionTemplates} = require './mail-rules-templates'

ChangeUnreadTask = require './flux/tasks/change-unread-task'
ChangeFolderTask = require './flux/tasks/change-folder-task'
ChangeStarredTask = require './flux/tasks/change-starred-task'
ChangeLabelsTask = require './flux/tasks/change-labels-task'

###
Note: At first glance, it seems like these task factory methods should use the
TaskFactory. Unfortunately, the TaskFactory uses the CategoryStore and other
information about the current view. Maybe after the unified inbox refactor...
###
MailRulesActions =
  markAsImportant: (message, thread) ->
    DatabaseStore.findBy(Label, {
      name: 'important',
      accountId: thread.accountId
    }).then (important) ->
      new ChangeLabelsTask(labelsToAdd: [important], threads: [thread])

  moveToTrash: (message, thread) ->
    account = AccountStore.itemWithId(thread.accountId)
    CategoryClass = account.categoryClass()
    TaskClass = if CategoryClass is Label then ChangeLabelsTask else ChangeFolderTask

    Promise.props(
      inbox: DatabaseStore.findBy(CategoryClass, { name: 'inbox', accountId: thread.accountId })
      trash: DatabaseStore.findBy(CategoryClass, { name: 'trash', accountId: thread.accountId })
    ).then ({inbox, trash}) ->
      new TaskClass
        labelsToRemove: [inbox]
        labelsToAdd: [trash]
        threads: [thread]

  markAsRead: (message, thread, value) ->
    new ChangeUnreadTask(unread: false, threads: [thread])

  star: (message, thread, value) ->
    new ChangeStarredTask(starred: true, threads: [thread])

  applyLabel: (message, thread, value) ->
    new ChangeLabelsTask(labelsToAdd: [value], threads: [thread])

  applyLabelArchive: (message, thread, value) ->
    Promise.props(
      inbox: DatabaseStore.findBy(Label, { name: 'inbox', accountId: thread.accountId })
      all: DatabaseStore.findBy(Label, { name: 'all', accountId: thread.accountId })
    ).then ({inbox, all}) ->
      new ChangeLabelsTask
        labelsToRemove: [inbox]
        labelsToAdd: [all]
        threads: [thread]

  changeFolder: (message, thread, value) ->
    new ChangeFolderTask(folder: value, threads: [thread])


class MailRulesProcessor
  constructor: ->

  processMessages: (messages) =>
    return Promise.resolve() unless messages.length > 0

    # When messages arrive, we process all the messages in parallel, but one
    # rule at a time. This is important, because users can order rules which
    # may do and undo a change. Ie: "Star if from Ben, Unstar if subject is "Bla"
    Promise.each MailRulesStore.rules(), (rule) =>
      matching = messages.filter (message) =>
        @_checkRuleForMessage(rule, message)

      # Rules are declared at the message level, but actions are applied to
      # threads. To ensure we don't apply the same action 50x on the same thread,
      # just process one match per thread.
      matching = _.uniq matching, false, (message) ->
        message.threadId

      Promise.map matching, (message) =>
        # We always pull the thread from the database, even though it may be in
        # `incoming.thread`, because rules may be modifying it as they run!
        DatabaseStore.find(Thread, message.threadId).then (thread) =>
          @_applyRuleToMessage(rule, message, thread)

  _checkRuleForMessage: (rule, message) =>
    if rule.conditionMode is ConditionMode.All
      fn = _.every
    else
      fn = _.any

    return false unless message.accountId is rule.accountId

    fn rule.conditions, (condition) =>
      template = _.findWhere(ConditionTemplates, {key: condition.templateKey})
      value = template.valueForMessage(message)
      template.evaluate(condition, value)

  _applyRuleToMessage: (rule, message, thread) =>
    results = rule.actions.map (action) =>
      MailRulesActions[action.templateKey](message, thread, action.value)

    Promise.all(results).then (results) ->
      performLocalPromises = []

      tasks = results.filter (r) -> r instanceof Task
      tasks.forEach (task) ->
        performLocalPromises.push TaskQueueStatusStore.waitForPerformLocal(task)
        Actions.queueTask(task)

      Promise.all(performLocalPromises)

module.exports = new MailRulesProcessor
