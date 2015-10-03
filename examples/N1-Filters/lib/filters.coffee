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

      React.createElement("div", {"className": "container-filters", "style": (padding: "0 15px")},
        (@_renderFocusedFilter @state.focusedFilter)
      )

    else

      React.createElement("div", {"className": "container-filters", "style": (padding: "0 15px")},
        (@state.filters.map @_renderFilter),
        React.createElement("div", {"className": "text-center", "style": (marginTop: 30)},
          React.createElement("button", {"className": "btn btn-large",  \
                  "onClick": ( => @_focus {} )}, """
            Create a new filter
""")
        )
      )

  _renderFocusedFilter: ({criteria, actions}) =>
    criteria ?= {}
    actions ?= {}

    # Gmail users have labels. Exchange users have Folders. They are implemented
    # differently and frequently require different functionality when you're
    # trying to manipulate either folders or labels.
    if CategoryStore.categoryLabel() is "Labels"
      applyCategory = React.createElement("label", null,
        React.createElement("input", {"type": "checkbox",  \
               "checked": (actions.applyLabel)}), """
        Apply the label:
""", React.createElement("select", {"value": (actions.applyLabel ? ""),  \
                "onChange": ((e) => @_changeAttr "actions", "applyLabel", e.target.value)},
          React.createElement("option", {"value": ""}, "Choose a label..."),
          (@state.categories.map (c) =>
            React.createElement("option", {"value": (c.id)}, (c.displayName)))
        )
      )
    else
      applyCategory = React.createElement("label", null,
        React.createElement("input", {"type": "checkbox",  \
               "checked": (actions.applyFolder)}), """
        Apply the folder:
""", React.createElement("select", {"value": (actions.applyFolder ? ""),  \
                "onChange": ((e) => @_changeAttr "actions", "applyFolder", e.target.value)},
          React.createElement("option", {"value": ""}, "Choose a folder..."),
          (@state.categories.map (c) =>
            React.createElement("option", {"value": (c.id)}, (c.displayName)))
        )
      )

    React.createElement("div", null,
      React.createElement("h4", null, "Filter criteria:"),
      React.createElement("label", {"className": "filter-input-label"}, "From:"),
      React.createElement("div", null,
        React.createElement("input", {"type": "text",  \
               "className": "filter-input",  \
               "value": (criteria.from),  \
               "onChange": ((e) => @_changeAttr "criteria", "from", e.target.value),  \
               "placeholder": "sender@email.com"})
      ),
      React.createElement("div", {"style": (clear: "both")}),
      React.createElement("label", {"className": "filter-input-label"}, "To:"),
      React.createElement("div", null,
        React.createElement("input", {"type": "text",  \
               "className": "filter-input",  \
               "value": (criteria.to),  \
               "onChange": ((e) => @_changeAttr "criteria", "to", e.target.value),  \
               "placeholder": "recipient@email.com"})
      ),
      React.createElement("div", {"style": (clear: "both")}),
      React.createElement("label", {"className": "filter-input-label"}, "Subject:"),
      React.createElement("div", null,
        React.createElement("input", {"type": "text",  \
               "className": "filter-input",  \
               "value": (criteria.subject),  \
               "onChange": ((e) => @_changeAttr "criteria", "subject", e.target.value),  \
               "placeholder": "subject contains this phrase"})
      ),
      React.createElement("div", {"style": (clear: "both")}),
      React.createElement("label", {"className": "filter-input-label"}, "Has words:"),
      React.createElement("div", null,
        React.createElement("input", {"type": "text",  \
               "className": "filter-input",  \
               "value": (criteria["has-words"]),  \
               "onChange": ((e) => @_changeAttr "criteria", "has-words", e.target.value),  \
               "placeholder": "subject or body contains this phrase"})
      ),
      React.createElement("div", {"style": (clear: "both")}),
      React.createElement("label", {"className": "filter-input-label"}, "Doesn\'t have:"),
      React.createElement("div", null,
        React.createElement("input", {"type": "text",  \
               "className": "filter-input",  \
               "value": (criteria["doesnt-have"]),  \
               "onChange": ((e) => @_changeAttr "criteria", "doesnt-have", e.target.value),  \
               "placeholder": "subject and body don't contain this phrase"})
      ),
      React.createElement("div", {"style": (clear: "both")}),

      React.createElement("h4", null, "When a message arrives that matches this search:"),
      React.createElement("div", null,
        React.createElement("label", null,
          React.createElement("input", {"type": "checkbox",  \
                 "onChange": ((e) => @_changeAttr "actions", "archive", e.target.checked),  \
                 "checked": (actions.archive)}), """
          Skip the inbox (Archive it)
""")
      ),
      React.createElement("div", null,
        React.createElement("label", null,
          React.createElement("input", {"type": "checkbox",  \
                 "onChange": ((e) => @_changeAttr "actions", "markAsRead", e.target.checked),  \
                 "checked": (actions.markAsRead)}), """
          Mark as read
""")
      ),
      React.createElement("div", null,
        React.createElement("label", null,
          React.createElement("input", {"type": "checkbox",  \
                 "onChange": ((e) => @_changeAttr "actions", "star", e.target.checked),  \
                 "checked": (actions.star)}), """
          Star it
""")
      ),
      React.createElement("div", null,
        (applyCategory)
      ),
      React.createElement("div", null,
        React.createElement("label", null,
          React.createElement("input", {"type": "checkbox",  \
                 "onChange": ((e) => @_changeAttr "actions", "delete", e.target.checked),  \
                 "checked": (actions.delete)}), """
          Delete it
""")
      ),

      React.createElement("h1", null),
      React.createElement("div", null,
        React.createElement("button", {"className": "btn pull-right",  \
                "onClick": (@_save)}, """
          Save filter
"""),
        React.createElement("button", {"className": "btn",  \
                "onClick": (@_unfocus)}, """
          Cancel
""")
      )
    )

  _renderFilter: (filter) =>
    buttonStyles = paddingLeft: 15
    lineItemStyles =
      whiteSpace: "nowrap"
      overflow: "auto"

    React.createElement("div", {"className": "filter-item", "key": (filter.id)},
      React.createElement("div", null,
        React.createElement("div", {"className": "pull-right action-button",  \
             "onClick": ( => @_focus filter )}, "edit"),
        React.createElement("div", {"className": "line-item"},
          React.createElement("span", null, "Matches: "),
          React.createElement("strong", null, (@_criteriaDisplay filter.criteria))
        )
      ),
      React.createElement("div", null,
        React.createElement("div", {"className": "pull-right action-button",  \
             "onClick": ( => @_delete filter.id )}, "delete"),
        React.createElement("div", {"className": "line-item"},
          React.createElement("span", null, "Do this: "),
          (@_actionsDisplay filter.actions)
        )
      )
    )

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
