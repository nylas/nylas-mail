Reflux = require 'reflux'
_ = require 'underscore-plus'
remote = require 'remote'

{NamespaceStore,
 Contact,
 Message,
 Actions,
 DatabaseStore} = require 'inbox-exports'

PlaygroundActions = require './playground-actions'
SearchStore = require './search-store'

module.exports =
RelevanceStore = Reflux.createStore
  init: ->
    @listenTo SearchStore, @_onSearchChanged
    @listenTo PlaygroundActions.setRankNext, @_onSetRankNext
    @listenTo PlaygroundActions.clearRanks, @_onClearRanks
    @listenTo PlaygroundActions.submitRanks, @_onSubmitRanks

  valueForId: (id) ->
    @_values[id]

  _onSubmitRanks: ->
    v = SearchStore.view()
    if @_valuesOrdered.length is 0
      return

    data =
      namespaceId: NamespaceStore.current().id
      query: SearchStore.searchQuery()
      weights: SearchStore.searchWeights()
      returned: [0..Math.min(9, v.count())].map (i) -> v.get(i)?.id
      desired: @_valuesOrdered

    draft = new Message
      from: [NamespaceStore.current().me()]
      to: [new Contact(name: "Nilas Team", email: "feedback@nilas.com")]
      date: (new Date)
      draft: true
      subject: "Feedback - Search Result Ranking"
      namespaceId: NamespaceStore.current().id
      body: JSON.stringify(data, null, '\t')

    DatabaseStore.persistModel(draft).then =>
      DatabaseStore.localIdForModel(draft).then (localId) ->
        Actions.sendDraft(localId)
        dialog = remote.require('dialog')
        dialog.showMessageBox remote.getCurrentWindow(), {
          type: 'warning'
          buttons: ['OK'],
          message: "Thank you."
          detail: "Your preferred ranking order for this query has been sent to the Edgehill team."
        }
      @_onClearRanks()

  _onClearRanks: ->
    @_values = {}
    @_valuesOrdered = []
    @_valueLast = 0
    @trigger(@)
    
  _onSetRankNext: (id) ->
    @_values[id] = @_valueLast += 1
    @_valuesOrdered.push(id)
    @trigger(@)

  _onSearchChanged: ->
    v = SearchStore.view()
    @_values = {}
    @_valuesOrdered = []
    @_valueLast = 0
    @trigger(@)
