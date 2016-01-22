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
      return Promise.reject(new Error("Could not find `important` label")) unless important
      return new ChangeLabelsTask(labelsToAdd: [important], threads: [thread])

  moveToTrash: (message, thread) ->
    if AccountStore.itemWithId(thread.accountId).categoryClass() is Label
      return MailRulesActions._applyStandardLabelRemovingInbox(message, thread, 'trash')
    else
      DatabaseStore.findBy(Folder, { name: 'trash', accountId: thread.accountId }).then (folder) ->
        return Promise.reject(new Error("The folder could not be found.")) unless folder
        return new ChangeFolderTask(folder: folder, threads: [thread])

  markAsRead: (message, thread) ->
    new ChangeUnreadTask(unread: false, threads: [thread])

  star: (message, thread) ->
    new ChangeStarredTask(starred: true, threads: [thread])

  changeFolder: (message, thread, value) ->
    return Promise.reject(new Error("A folder is required.")) unless value
    DatabaseStore.findBy(Folder, { id: value, accountId: thread.accountId }).then (folder) ->
      return Promise.reject(new Error("The folder could not be found.")) unless folder
      return new ChangeFolderTask(folder: folder, threads: [thread])

  applyLabel: (message, thread, value) ->
    return Promise.reject(new Error("A label is required.")) unless value
    DatabaseStore.findBy(Label, { id: value, accountId: thread.accountId }).then (label) ->
      return Promise.reject(new Error("The label could not be found.")) unless label
      return new ChangeLabelsTask(labelsToAdd: [label], threads: [thread])

  applyLabelArchive: (message, thread) ->
    return MailRulesActions._applyStandardLabelRemovingInbox(message, thread, 'all')

  # Helpers for other actions

  _applyStandardLabelRemovingInbox: (message, thread, value) ->
    Promise.props(
      inbox: DatabaseStore.findBy(Label, { name: 'inbox', accountId: thread.accountId })
      newLabel: DatabaseStore.findBy(Label, { name: value, accountId: thread.accountId })
    ).then ({inbox, newLabel}) ->
      return Promise.reject(new Error("Could not find `inbox` or `#{value}` label")) unless inbox and newLabel
      return new ChangeLabelsTask
        labelsToRemove: [inbox]
        labelsToAdd: [newLabel]
        threads: [thread]


class MailRulesProcessor
  constructor: ->

  processMessages: (messages) =>
    return Promise.resolve() unless messages.length > 0

    enabledRules = MailRulesStore.rules().filter (r) -> not r.disabled

    # When messages arrive, we process all the messages in parallel, but one
    # rule at a time. This is important, because users can order rules which
    # may do and undo a change. Ie: "Star if from Ben, Unstar if subject is "Bla"
    Promise.each enabledRules, (rule) =>
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
          return console.warn("Cannot find thread #{message.threadId} to process mail rules.") unless thread
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
    actionPromises = rule.actions.map (action) =>
      actionFunction = MailRulesActions[action.templateKey]
      if not actionFunction
        return Promise.reject(new Error("#{action.templateKey} is not a supported action."))
      return actionFunction(message, thread, action.value)

    Promise.all(actionPromises).then (actionResults) ->
      performLocalPromises = []

      actionTasks = actionResults.filter (r) -> r instanceof Task
      actionTasks.forEach (task) ->
        performLocalPromises.push TaskQueueStatusStore.waitForPerformLocal(task)
        Actions.queueTask(task)

      Promise.all(performLocalPromises)

    .catch (err) ->
      # Errors can occur if a mail rule specifies an invalid label or folder, etc.
      # Disable the rule. Disable the mail rule so the failure is reflected in the
      # interface.
      Actions.disableMailRule(rule.id, err.toString())
      return Promise.resolve()

module.exports = new MailRulesProcessor
