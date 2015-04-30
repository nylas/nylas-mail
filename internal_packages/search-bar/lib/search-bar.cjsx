React = require 'react/addons'
classNames = require 'classnames'
{Actions} = require 'inbox-exports'
{Menu, RetinaImg} = require 'ui-components'
SearchSuggestionStore = require './search-suggestion-store'
_ = require 'underscore-plus'


class SearchBar extends React.Component
  @displayName = 'SearchBar'

  constructor: (@props) ->
    @state =
      query: ""
      focused: false
      suggestions: []
      committedQuery: null

  componentDidMount: =>
    @unsubscribe = SearchSuggestionStore.listen @_onStoreChange
    @body_unsubscriber = atom.commands.add 'body', {
      'application:focus-search': @_onFocusSearch
    }
    @search_unsubscriber = atom.commands.add '.search-bar', {
      'search-bar:escape-search': @_clearAndBlur
    }

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: =>
    @unsubscribe()
    @body_unsubscriber.dispose()
    @search_unsubscriber.dispose()

  render: =>
    inputValue = @_queryToString(@state.query)
    inputClass = classNames
      'input-bordered': true
      'empty': inputValue.length is 0

    headerComponents = [
      <input type="text"
             ref="searchInput"
             key="input"
             className={inputClass}
             placeholder="Search all email"
             value={inputValue}
             onChange={@_onValueChange}
             onFocus={@_onFocus}
             onBlur={@_onBlur} />

      <RetinaImg className="search-accessory search"
                 name="searchloupe.png"
                 key="accessory"
                 onClick={@_doSearch} />
      <div className="search-accessory clear"
           key="clear"
           onClick={@_onClearSearch}><i className="fa fa-remove"></i></div>
    ]

    itemContentFunc = (item) =>
      if item.divider
        <Menu.Item divider={item.divider} />
      else if item.contact
        <Menu.NameEmailItem name={item.contact.name} email={item.contact.email} />
      else
        item.label

    <div className="search-bar">
      <Menu ref="menu"
        className={@_containerClasses()}
        headerComponents={headerComponents}
        items={@state.suggestions}
        itemContent={itemContentFunc}
        itemKey={ (item) -> item.label }
        onSelect={@_onSelectSuggestion}
        />
    </div>

  _onFocusSearch: =>
    React.findDOMNode(@refs.searchInput).focus()

  _containerClasses: =>
    classNames
      'focused': @state.focused
      'showing-query': @state.query?.length > 0
      'committed-query': @state.committedQuery?.length > 0
      'search-container': true
      'showing-suggestions': @state.suggestions?.length > 0

  _queryToString: (query) =>
    return "" unless query instanceof Array
    str = ""
    for term in query
      for key,val of term
        if key == "all"
          str += val
        else
          str += "#{key}:#{val}"

  _stringToQuery: (str) =>
    return [] unless str

    # note: right now this only works if there's one term. In the future,
    # we'll make this whole search input a tokenizing field
    [a,b] = str.split(':')
    term = {}
    if b
      term[a] = b
    else
      term["all"] = a
    [term]

  _onValueChange: (event) =>
    Actions.searchQueryChanged(@_stringToQuery(event.target.value))
    if (event.target.value is '')
      @_onClearSearch()

  _onSelectSuggestion: (item) =>
    Actions.searchQueryCommitted(item.value)

  _onClearSearch: (event) =>
    Actions.searchQueryCommitted(null)

  _clearAndBlur: =>
    @_onClearSearch()
    React.findDOMNode(@refs.searchInput)?.blur()

  _onFocus: =>
    @setState focused: true

  _onBlur: =>
    # Don't immediately hide the menu when the text input is blurred,
    # because the user might have clicked an item in the menu. Wait to
    # handle the touch event, then dismiss the menu.
    setTimeout =>
      Actions.searchBlurred()
      @setState(focused: false)
    , 150

  _doSearch: =>
    Actions.searchQueryCommitted(@state.query)

  _onStoreChange: =>
    @setState
      query: SearchSuggestionStore.query()
      suggestions: SearchSuggestionStore.suggestions()
      committedQuery: SearchSuggestionStore.committedQuery()


module.exports = SearchBar