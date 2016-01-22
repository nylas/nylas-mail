NylasStore = require 'nylas-store'
_ = require 'underscore'
Rx = require 'rx-lite'
AccountStore = require './account-store'
DatabaseStore = require './database-store'
TaskQueueStatusStore = require './task-queue-status-store'
Utils = require '../models/utils'
Actions = require '../actions'

{ConditionMode, ConditionTemplates, ActionTemplates} = require '../../mail-rules-templates'

RulesJSONBlobKey = "MailRules-V2"

class MailRulesStore extends NylasStore
  constructor: ->
    query = DatabaseStore.findJSONBlob(RulesJSONBlobKey)
    @_subscription = Rx.Observable.fromQuery(query).subscribe (rules) =>
      @_rules = rules ? []
      @trigger()

    @listenTo Actions.addMailRule, @_onAddMailRule
    @listenTo Actions.deleteMailRule, @_onDeleteMailRule
    @listenTo Actions.updateMailRule, @_onUpdateMailRule
    @listenTo Actions.disableMailRule, @_onDisableMailRule
    @listenTo Actions.notificationActionTaken, @_onNotificationActionTaken

  rules: =>
    @_rules

  rulesForAccountId: (accountId) =>
    @_rules.filter (f) => f.accountId is accountId

  _onDeleteMailRule: (id) =>
    @_rules = @_rules.filter (f) -> f.id isnt id
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

    Actions.postNotification
      message: "We were unable to run your mail rules - one or more rules have been disabled."
      type: "error"
      tag: 'mail-rule-failure'
      sticky: true
      actions: [{
        label: 'Hide'
        dismisses: true
        id: 'hide'
      },{
        label: 'View Rules'
        dismisses: true
        default: true
        id: 'mail-rule-failure:view-rules'
      }]

    # Disable the task
    existing.disabled = true
    existing.disabledReason = reason
    @_saveMailRules()

    # Cancel all bulk processing jobs
    for task in TaskQueueStatusStore.tasksMatching(ReprocessMailRulesTask, {})
      Actions.dequeueTask(task.id)

    @trigger()

  _onNotificationActionTaken: ({notification, action}) =>
    return unless NylasEnv.isMainWindow()
    if action.id is 'mail-rule-failure:view-rules'
      Actions.switchPreferencesTab('Mail Rules', {accountId: AccountStore.current().id})
      Actions.openPreferences()

  _saveMailRules: =>
    @_saveMailRulesDebounced ?= _.debounce =>
      DatabaseStore.inTransaction (t) =>
        t.persistJSONBlob(RulesJSONBlobKey, @_rules)

      if not _.findWhere(@_rules, {disabled: true})
        Actions.dismissNotificationsMatching({tag: 'mail-rule-failure'})
    ,1000
    @_saveMailRulesDebounced()


module.exports = new MailRulesStore()
