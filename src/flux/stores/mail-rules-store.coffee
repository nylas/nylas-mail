NylasStore = require 'nylas-store'
_ = require 'underscore'
Rx = require 'rx-lite'
DatabaseStore = require './database-store'
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

  _saveMailRules: =>
    @_saveMailRulesDebounced ?= _.debounce =>
      DatabaseStore.inTransaction (t) =>
        t.persistJSONBlob(RulesJSONBlobKey, @_rules)
    ,1000
    @_saveMailRulesDebounced()


module.exports = new MailRulesStore()
