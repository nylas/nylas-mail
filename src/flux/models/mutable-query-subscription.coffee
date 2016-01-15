QuerySubscription = require './query-subscription'

class MutableQuerySubscription extends QuerySubscription
  constructor: ->
    super

  replaceQuery: (nextQuery) =>
    return if @_query?.sql() is nextQuery.sql()

    rangeIsOnlyChange = @_query?.clone().offset(0).limit(0).sql() is nextQuery.clone().offset(0).limit(0).sql()

    nextQuery.finalize()
    @_query = nextQuery
    @_set = null unless @_set and rangeIsOnlyChange
    @update()

  replaceRange: ({start, end}) =>
    @replaceQuery(@_query.clone().page(start, end))

module.exports = MutableQuerySubscription
