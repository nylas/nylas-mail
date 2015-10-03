React = require 'react'
_ = require 'underscore'
# Flux uses Stores to perform business logic and be the single source of truth
# for data to render in the application.
FiltersStore = require './filters-store'
{CategoryStore, Actions, Utils} = require 'nylas-exports'
# `RetinaImg` is a React component for optimistically rendering images for
# Retina displays but falling back on normal images if needed.
{RetinaImg} = require 'nylas-component-kit'

class Filters extends React.Component
  # Having a `@displayName` is a React best practice to make debugging easier.
  @displayName: 'Filters'

  # Setting the component's initial state.
  constructor: ->
    @state = @_getStateFromStores()

  # For Flux, we want the Stores to publish its changes to all subscribed React
  # components. React components can subscribe to views in `componentDidMount`.
  # When they receive new changes from stores, then the component's callbacks
  # fire.
  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push FiltersStore.listen @_onFiltersChange
    @_unsubscribers.push CategoryStore.listen @_onCategoriesChange

  # Don't forget to unsubscribe from your stores on `componentWillUnmount`!
  # If you don't, the callbacks will still exist, but the components that the
  # callbacks are trying to update won't exist anymore. React will then throw
  # an exception.
  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  render: =>
    if @state.focusedFilter

      <div className="container-filters" style={padding: "0 15px"}>
        {@_renderFocusedFilter @state.focusedFilter}
      </div>

    else

      <div className="container-filters" style={padding: "0 15px"}>
        {@state.filters.map @_renderFilter}
        <div className="text-center" style={marginTop: 30}>
          <button className="btn btn-large"
                  onClick={ => @_focus {} }>
            Create a new filter
          </button>
        </div>
      </div>

  _renderFocusedFilter: ({criteria, actions}) =>
    criteria ?= {}
    actions ?= {}

    # Gmail users have labels. Exchange users have Folders. They are implemented
    # differently and frequently require different functionality when you're
    # trying to manipulate either folders or labels.
    if CategoryStore.categoryLabel() is "Labels"
      applyCategory = <label>
        <input type="checkbox"
               checked={actions.applyLabel} />
        Apply the label:
        <select value={actions.applyLabel ? ""}
                onChange={(e) => @_changeAttr "actions", "applyLabel", e.target.value}>
          <option value="">Choose a label...</option>
          {@state.categories.map (c) =>
            <option value={c.id}>{c.displayName}</option>}
        </select>
      </label>
    else
      applyCategory = <label>
        <input type="checkbox"
               checked={actions.applyFolder} />
        Apply the folder:
        <select value={actions.applyFolder ? ""}
                onChange={(e) => @_changeAttr "actions", "applyFolder", e.target.value}>
          <option value="">Choose a folder...</option>
          {@state.categories.map (c) =>
            <option value={c.id}>{c.displayName}</option>}
        </select>
      </label>

    <div>
      <h4>Filter criteria:</h4>
      <label className="filter-input-label">From:</label>
      <div>
        <input type="text"
               className="filter-input"
               value={criteria.from}
               onChange={(e) => @_changeAttr "criteria", "from", e.target.value}
               placeholder="sender@email.com" />
      </div>
      <div style={clear: "both"}></div>
      <label className="filter-input-label">To:</label>
      <div>
        <input type="text"
               className="filter-input"
               value={criteria.to}
               onChange={(e) => @_changeAttr "criteria", "to", e.target.value}
               placeholder="recipient@email.com" />
      </div>
      <div style={clear: "both"}></div>
      <label className="filter-input-label">Subject:</label>
      <div>
        <input type="text"
               className="filter-input"
               value={criteria.subject}
               onChange={(e) => @_changeAttr "criteria", "subject", e.target.value}
               placeholder="subject contains this phrase" />
      </div>
      <div style={clear: "both"}></div>
      <label className="filter-input-label">Has words:</label>
      <div>
        <input type="text"
               className="filter-input"
               value={criteria["has-words"]}
               onChange={(e) => @_changeAttr "criteria", "has-words", e.target.value}
               placeholder="subject or body contains this phrase" />
      </div>
      <div style={clear: "both"}></div>
      <label className="filter-input-label">Doesn't have:</label>
      <div>
        <input type="text"
               className="filter-input"
               value={criteria["doesnt-have"]}
               onChange={(e) => @_changeAttr "criteria", "doesnt-have", e.target.value}
               placeholder="subject and body don't contain this phrase" />
      </div>
      <div style={clear: "both"}></div>

      <h4>When a message arrives that matches this search:</h4>
      <div>
        <label>
          <input type="checkbox"
                 onChange={(e) => @_changeAttr "actions", "archive", e.target.checked}
                 checked={actions.archive} />
          Skip the inbox (Archive it)
        </label>
      </div>
      <div>
        <label>
          <input type="checkbox"
                 onChange={(e) => @_changeAttr "actions", "markAsRead", e.target.checked}
                 checked={actions.markAsRead} />
          Mark as read
        </label>
      </div>
      <div>
        <label>
          <input type="checkbox"
                 onChange={(e) => @_changeAttr "actions", "star", e.target.checked}
                 checked={actions.star} />
          Star it
        </label>
      </div>
      <div>
        {applyCategory}
      </div>
      <div>
        <label>
          <input type="checkbox"
                 onChange={(e) => @_changeAttr "actions", "delete", e.target.checked}
                 checked={actions.delete} />
          Delete it
        </label>
      </div>

      <h1></h1>
      <div>
        <button className="btn pull-right"
                onClick={@_save}>
          Save filter
        </button>
        <button className="btn"
                onClick={@_unfocus}>
          Cancel
        </button>
      </div>
    </div>

  _renderFilter: (filter) =>
    buttonStyles = paddingLeft: 15
    lineItemStyles =
      whiteSpace: "nowrap"
      overflow: "auto"

    <div className="filter-item" key={filter.id}>
      <div>
        <div className="pull-right action-button"
             onClick={ => @_focus filter }>edit</div>
        <div className="line-item">
          <span>Matches: </span>
          <strong>{@_criteriaDisplay filter.criteria}</strong>
        </div>
      </div>
      <div>
        <div className="pull-right action-button"
             onClick={ => @_delete filter.id }>delete</div>
        <div className="line-item">
          <span>Do this: </span>
          {@_actionsDisplay filter.actions}
        </div>
      </div>
    </div>

  _changeAttr: (attr1, attr2, val) =>
    f = @state.focusedFilter
    f[attr1] ?= {}
    f[attr1][attr2] = val
    @setState focusedFilter: f

  _focus: (filter) =>
    @setState focusedFilter: Utils.deepClone(filter)

  _unfocus: =>
    @setState focusedFilter: null

  _delete: (id) =>
    # React components trigger changes by firing Actions, which is simply
    # invoking an Actions function with relevant data as arguments. Stores will
    # listen to Actions and update themselves accordingly.
    Actions.deleteFilter id;

  _save: =>
    Actions.saveFilter @state.focusedFilter
    @_unfocus()

  _criterionDisplay: (val, criterion) ->
    "#{criterion}(#{val})"

  _criteriaDisplay: (criteria) =>
    _.map(criteria, @_criterionDisplay)
      .join(" ")

  _actionDisplay: (val, action) =>
    if action is "applyLabel"
      category = _.find @state.categories, (c) ->
        c.id is val
      "Apply label \"#{category.displayName}\""
    else if action is "applyFolder"
      category = _.find @state.categories, (c) ->
        c.id is val
      "Apply folder \"#{category.displayName}\""
    else if action is "markAsRead" and val is true
      "Mark as read"
    else if action is "archive" and val is true
      "Skip the inbox (Archive it)"
    else if action is "star" and val is true
      "Star it"
    else if action is "delete" and val is true
      "Delete it"

  _actionsDisplay: (actions) =>
    _.map(actions, @_actionDisplay)
      .join(", ")

  _getStateFromStores: =>
    # A common N1 pattern is to dedicate a method solely to generating state,
    # like right here. It's usually called by the constructor and by listener
    # callbacks to Stores.
    filters: FiltersStore.filters()
    categories: CategoryStore.getUserCategories()

  # Here's the callback that fires after Stores publish changes! `@setState`
  # will trigger a render with new data.
  _onFiltersChange: =>
    @setState @_getStateFromStores()

module.exports = Filters
