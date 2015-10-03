NylasStore = require 'nylas-store'
_ = require 'underscore'
_s = require 'underscore.string'
{Actions, CategoryStore, AccountStore, ChangeLabelsTask,
 ChangeFolderTask, ArchiveThreadHelper, ChangeStarredTask,
 ChangeUnreadTask, Utils} = require 'nylas-exports'

# The FiltersStore performs all business logic for filters: the single source
# of truth for any other code using filters, the gateway to persisting data
# for filters, the subscriber to Actions which affect filters, and the
# publisher for all React components which render filters.
class FiltersStore extends NylasStore

  # The store's instantiation is the best time during the store life cycle
  # to both set the store's initial state and also subscribe to Actions which
  # will be published elsewhere.
  constructor: ->

    # ...here, we're setting initial state...
    @_filters = @_loadFilters()

    # ...and here, we're subscribing to Actions which could be fired by React
    # components, other stores, or any other part of the application.
    @listenTo Actions.deleteFilter, @_onDeleteFilter
    @listenTo Actions.didPassivelyReceiveNewModels, @_onNewModels
    @listenTo Actions.saveFilter, @_onSaveFilter

  # This method is the application's single source of truth for filters.
  # All FiltersStore consumers will invoke it to get the canonical filters at
  # the present moment.
  filters: =>
    @_filters

  # The callback for Action.deleteFilter. This action's publishers will pass to
  # the callback a filter id for the filter to be deleted.
  _onDeleteFilter: (id) =>
    newFilters = @_filters.filter (f) ->
      f.id isnt id
    @_writeAndPublishChanges newFilters

  # The callback for Action.saveFilter. This action's publishers will pass a
  # filter object. If the published object contains an id, then we assume we're
  # updating an existing filter. Otherwise, we assume we're creating a new one.
  _onSaveFilter: (filter) =>
    updatingExistingFilter = !!filter.id

    if updatingExistingFilter
      updatedFilter = _.find @_filters, (f) -> f.id is filter.id
      index = _.indexOf @_filters, updatedFilter
      @_filters[index] = filter
    else
      filter.id = Utils.generateTempId()
      @_filters.push filter

    @_writeAndPublishChanges @_filters

  _writeAndPublishChanges: (filters) =>
    @_saveFilters filters
    @_filters = filters

    # @trigger publishes to all React components subscribed to the FiltersStore.
    # This tells the React components that the store's underlying data has
    # changed. React components will update according to the new changes.
    @trigger()

  # For filters, an `action` is performed when an incoming message matches a
  # filter's criteria. An action could be marking the message as read. These
  # actions are just N1 `Task` instances which will be queued to run by
  # `Actions.queueTask`.
  _makeActions: (filters, thread) ->
    _.chain filters
      .pluck 'actions'
      .map _.pairs
      .flatten true
      .map ([action, val]) ->
        if action is "applyLabel"
          label = _.find CategoryStore.getUserCategories(), (c) ->
            c.id is val
          new ChangeLabelsTask
            labelsToAdd: [label]
            threads: [thread]
        else if action is "applyFolder"
          folder = _.find CategoryStore.getUserCategories(), (c) ->
            c.id is val
          new ChangeFolderTask
            folder: folder
            threads: [thread]
        else if action is "markAsRead" and val is true
          new ChangeUnreadTask
            unread: false
            threads: [thread]
        else if action is "archive" and val is true
          ArchiveThreadHelper.getArchiveTask [thread]
        else if action is "star" and val is true
          new ChangeStarredTask
            starred: true
            threads: [thread]
        else if action is "delete" and val is true
          trash = CategoryStore.getStandardCategory "trash"

          # Some email providers use labels, like Gmail, and others use folders,
          # like Microsoft Exchange. Labels and folders behave very differently,
          # so there are different Task classes to modify records for them.
          if AccountStore.current().usesFolders()
            new ChangeFolderTask
              folder: trash
              threads: [thread]
          else
            new ChangeLabelsTask
              labelsToAdd: [trash]
              threads: [thread]
      .value()

  _getPassedFilters: ({message, thread}) =>
    @_filters.filter ({criteria}) ->
      _.every criteria, (val, criterion) ->
        if criterion is "from"
          _.find message.from, (contact) -> contact.email is val
        else if criterion is "to"
          _.find message.to, (contact) -> contact.email is val
        else if criterion is "subject"
          _s.contains thread.subject, val
        else if criterion is "has-words"
          _s.contains(thread.subject, val) or _s.contains(message.body, val)
        else if criterion is "doesnt-have"
          not _s.contains(thread.subject, val) and
          not _s.contains(message.body, val)

  _getFilterActions: (incoming) =>

    # The data structure representing all incoming models is a key-value hash
    # with the model type as the key and an array of models as the value. Here,
    # we're just accessing the models themselves from the `incoming` data
    # structure.
    message = incoming.message[0]
    thread = incoming.thread[0]

    passedFilters = @_getPassedFilters {message, thread}
    @_makeActions passedFilters, thread

  # The callback for Action.didPassivelyReceiveNewModels, a global action which
  # is published every time the application receives new data from the server.
  _onNewModels: (incoming) =>

    # We ignore most incoming models, unless it's an incoming thread and
    # message. Those are the only models which are relevant to filters.
    if incoming.thread and incoming.message
      actions = @_getFilterActions incoming

      # Actions.queueTask will take N1 tasks, which we generically call
      # `actions` in this method, and implement all remote-client syncing work.
      # Actions.queueTask is N1's way of creating, updating, and deleting
      # records in the backend while maintaining canonical data in the frontend.
      Actions.queueTask(action) for action in actions

  # The filters are stored in the config.cson file.
  _loadFilters: =>
    atom.config.get('filters') ? []

  # Rewrite the filters to the config.cson file.
  _saveFilters: (filters) =>
    filters = @_trimFilters filters

    if @_validateFilters(filters)
      atom.config.set 'filters', filters
    else
      throw new Error("invalid filters")

  # Prune the filters data for saving. We don't want to save malformed data!
  _trimFilters: (filters) =>
    for filter in filters
      for attr in ["criteria", "actions"]
        for key, val of filter[attr]
          if not val
            delete filter[attr][key]

    return filters

  # Simple validation to be run when _saveFilters is invoked.
  _validateFilters: (filters) =>
    Array.isArray(filters) and filters.every (f) ->
      f.id? and f.criteria? and f.actions?


# A best practice is to export an instance of the FiltersStore, NOT the class!
module.exports = new FiltersStore()
