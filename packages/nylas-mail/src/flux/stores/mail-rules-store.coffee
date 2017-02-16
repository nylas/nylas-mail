NylasStore = require 'nylas-store'
_ = require 'underscore'
Rx = require 'rx-lite'
AccountStore = require('./account-store').default
DatabaseStore = require('./database-store').default
TaskQueueStatusStore = require './task-queue-status-store'
ReprocessMailRulesTask = require('../tasks/reprocess-mail-rules-task').default
Utils = require '../models/utils'
Actions = require('../actions').default

{ConditionMode, ConditionTemplates, ActionTemplates} = require '../../mail-rules-templates'

RulesJSONBlobKey = "MailRules-V2"

class MailRulesStore extends NylasStore
  constructor: ->
    @_rules = []

    query = DatabaseStore.findJSONBlob(RulesJSONBlobKey)
    @_subscription = Rx.Observable.fromQuery(query).subscribe (rules) =>
      @_rules = rules ? []
      @trigger()

    @listenTo Actions.addMailRule, @_onAddMailRule
    @listenTo Actions.deleteMailRule, @_onDeleteMailRule
    @listenTo Actions.reorderMailRule, @_onReorderMailRule
    @listenTo Actions.updateMailRule, @_onUpdateMailRule
    @listenTo Actions.disableMailRule, @_onDisableMailRule

  rules: =>
    @_rules

  rulesForAccountId: (accountId) =>
    @_rules.filter (f) => f.accountId is accountId

  disabledRules: (accountId) =>
    @_rules.filter (f) => f.disabled

  _onDeleteMailRule: (id) =>
    @_rules = @_rules.filter (f) -> f.id isnt id
    @_saveMailRules()
    @trigger()

  _onReorderMailRule: (id, newIdx) =>
    currentIdx = _.findIndex(@_rules, _.matcher({id}))
    return if currentIdx is -1
    rule = @_rules[currentIdx]
    @_rules.splice(currentIdx, 1)
    @_rules.splice(newIdx, 0, rule)
    @_saveMailRules()
    @trigger()

  _onAddMailRule: (properties) =>
    defaults =
      id: Utils.generateTempId()
      name: "Untitled Rule"
      conditionMode: ConditionMode.All
      conditions: [ConditionTemplates[0].createDefaultInstance()]
      actions: [ActionTemplates[0].createDefaultInstance()]
      disabled: false

    unless properties.accountId
      throw new Error("AddMailRule: you must provide an account id.")

    @_rules.push(_.extend(defaults, properties))
    @_saveMailRules()
    @trigger()

  _onUpdateMailRule: (id, properties) =>
    existing = _.find @_rules, (f) -> id is f.id
    existing[key] = val for key, val of properties
    @_saveMailRules()
    @trigger()

  _onDisableMailRule: (id, reason) =>
    existing = _.find @_rules, (f) -> id is f.id
    return if not existing or existing.disabled is true

    # Disable the task
    existing.disabled = true
    existing.disabledReason = reason
    @_saveMailRules()

    # Cancel all bulk processing jobs
    for task in TaskQueueStatusStore.tasksMatching(ReprocessMailRulesTask, {})
      Actions.dequeueTask(task.id)

    @trigger()

  _saveMailRules: =>
    @_saveMailRulesDebounced ?= _.debounce =>
      DatabaseStore.inTransaction (t) =>
        t.persistJSONBlob(RulesJSONBlobKey, @_rules)
    ,1000
    @_saveMailRulesDebounced()


module.exports = new MailRulesStore()
