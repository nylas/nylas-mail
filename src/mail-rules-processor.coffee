_ = require 'underscore'

Task = require('./flux/tasks/task').default
Actions = require('./flux/actions').default
Category = require('./flux/models/category').default
Thread = require('./flux/models/thread').default
Message = require('./flux/models/message').default
AccountStore = require('./flux/stores/account-store').default
DatabaseStore = require('./flux/stores/database-store').default
TaskQueueStatusStore = require './flux/stores/task-queue-status-store'

{ConditionMode, ConditionTemplates} = require './mail-rules-templates'

ChangeUnreadTask = require('./flux/tasks/change-unread-task').default
ChangeFolderTask = require('./flux/tasks/change-folder-task').default
ChangeStarredTask = require('./flux/tasks/change-starred-task').default
ChangeLabelsTask = require('./flux/tasks/change-labels-task').default
MailRulesStore = null

###
Note: At first glance, it seems like these task factory methods should use the
TaskFactory. Unfortunately, the TaskFactory uses the CategoryStore and other
information about the current view. Maybe after the unified inbox refactor...
###
MailRulesActions =
  markAsImportant: (message, thread) ->
    DatabaseStore.findBy(Category, {
      name: 'important',
      accountId: thread.accountId
    }).then (important) ->
      return Promise.reject(new Error("Could not find `important` label")) unless important
      return new ChangeLabelsTask(labelsToAdd: [important], threads: [thread.id], source: "Mail Rules")

  moveToTrash: (message, thread) ->
    if AccountStore.accountForId(thread.accountId).usesLabels()
      return MailRulesActions.moveToLabel(message, thread, 'trash')
    else
      DatabaseStore.findBy(Category, { name: 'trash', accountId: thread.accountId }).then (folder) ->
        return Promise.reject(new Error("The folder could not be found.")) unless folder
        return new ChangeFolderTask(folder: folder, threads: [thread.id], source: "Mail Rules")

  markAsRead: (message, thread) ->
    new ChangeUnreadTask(unread: false, threads: [thread.id], source: "Mail Rules")

  star: (message, thread) ->
    new ChangeStarredTask(starred: true, threads: [thread.id], source: "Mail Rules")

  changeFolder: (message, thread, value) ->
    return Promise.reject(new Error("A folder is required.")) unless value
    DatabaseStore.findBy(Category, { id: value, accountId: thread.accountId }).then (folder) ->
      return Promise.reject(new Error("The folder could not be found.")) unless folder
      return new ChangeFolderTask(folder: folder, threads: [thread.id], source: "Mail Rules")

  applyLabel: (message, thread, value) ->
    return Promise.reject(new Error("A label is required.")) unless value
    DatabaseStore.findBy(Category, { id: value, accountId: thread.accountId }).then (label) ->
      return Promise.reject(new Error("The label could not be found.")) unless label
      return new ChangeLabelsTask(labelsToAdd: [label], threads: [thread.id], source: "Mail Rules")

  # Should really be moveToArchive but stuck with legacy name
  applyLabelArchive: (message, thread) ->
    return MailRulesActions.moveToLabel(message, thread, 'all')

  moveToLabel: (message, thread, nameOrId) ->
    return Promise.reject(new Error("A label is required.")) unless nameOrId

    Promise.props(
      withId: DatabaseStore.findBy(Category, { id: nameOrId, accountId: thread.accountId })
      withName: DatabaseStore.findBy(Category, { name: nameOrId, accountId: thread.accountId })
    ).then ({withId, withName}) ->
      label = withId || withName
      return Promise.reject(new Error("The label could not be found.")) unless label
      return new ChangeLabelsTask({
        source: "Mail Rules"
        labelsToRemove: [].concat(thread.labels).filter((l) =>
          !l.isLockedCategory() and l.id isnt label.id
        ),
        labelsToAdd: [label],
        threads: [thread.id]
      })


class MailRulesProcessor
  constructor: ->

  processMessages: (messages) =>
    MailRulesStore ?= require './flux/stores/mail-rules-store'
    return Promise.resolve() unless messages.length > 0

    enabledRules = MailRulesStore.rules().filter (r) -> not r.disabled

    # When messages arrive, we process all the messages in parallel, but one
    # rule at a time. This is important, because users can order rules which
    # may do and undo a change. Ie: "Star if from Ben, Unstar if subject is "Bla"
    return Promise.each enabledRules, (rule) =>
      matching = messages.filter (message) =>
        @_checkRuleForMessage(rule, message)

      # Rules are declared at the message level, but actions are applied to
      # threads. To ensure we don't apply the same action 50x on the same thread,
      # just process one match per thread.
      matching = _.uniq matching, false, (message) ->
        message.threadId

      return Promise.map matching, (message) =>
        # We always pull the thread from the database, even though it may be in
        # `incoming.thread`, because rules may be modifying it as they run!
        DatabaseStore.find(Thread, message.threadId).then (thread) =>
          return console.warn("Cannot find thread #{message.threadId} to process mail rules.") unless thread
          return @_applyRuleToMessage(rule, message, thread)

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

      return Promise.all(performLocalPromises)

    .catch (err) ->
      # Errors can occur if a mail rule specifies an invalid label or folder, etc.
      # Disable the rule. Disable the mail rule so the failure is reflected in the
      # interface.
      Actions.disableMailRule(rule.id, err.toString())
      return Promise.resolve()

module.exports = new MailRulesProcessor
