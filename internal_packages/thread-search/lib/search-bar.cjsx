_ = require 'underscore'
React = require 'react'
ReactDOM = require 'react-dom'
classNames = require 'classnames'

{Actions,
 WorkspaceStore,
 FocusedPerspectiveStore} = require 'nylas-exports'
{Menu, RetinaImg, KeyCommandsRegion} = require 'nylas-component-kit'

SearchStore = require './search-store'
SearchActions = require './search-actions'

class SearchBar extends React.Component
  @displayName = 'SearchBar'

  constructor: (@props) ->
    @state = _.extend({}, @_getStateFromStores(), {
      focused: false
    },)

  componentDidMount: =>
    @usub = []
    @usub.push SearchStore.listen @_onChange
    @usub.push WorkspaceStore.listen =>
      @setState(focused: false) if @state.focused

  # It's important that every React class explicitly stops listening to
  # N1 events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: =>
    usub() for usub in @usub

  _keymapHandlers: ->
    'core:focus-search': @_onFocusSearch
    'search-bar:escape-search': @_clearAndBlur

  render: =>
    inputClass = classNames
      'empty': @state.query.length is 0

    loupeImg = if @state.isSearching
      <RetinaImg
        className="search-accessory search loading"
        name="inline-loading-spinner.gif"
        key="accessory"
        mode={RetinaImg.Mode.ContentPreserve}
      />
    else
      <RetinaImg
        className="search-accessory search"
        name="searchloupe.png"
        key="accessory"
        mode={RetinaImg.Mode.ContentDark}
        onClick={@_doSearch}
      />

    headerComponents = [
      <input type="text"
             ref="searchInput"
             key="input"
             className={inputClass}
             placeholder="Search all email"
             value={@state.query}
             onChange={@_onValueChange}
             onFocus={@_onFocus}
             onBlur={@_onBlur} />,
      loupeImg,
      <RetinaImg className="search-accessory clear"
                 name="searchclear.png"
                 key="clear"
                 mode={RetinaImg.Mode.ContentDark}
                 onClick={@_onClearSearch} />,
    ]

    itemContentFunc = (item) =>
      if item.divider
        <Menu.Item divider={item.divider} />
      else if item.contact
        <Menu.NameEmailItem name={item.contact.name} email={item.contact.email} />
      else if item.thread
        item.thread.subject
      else
        item.label

    <KeyCommandsRegion className="search-bar" globalHandlers={@_keymapHandlers()}>
      <div>
        <Menu ref="menu"
          className={@_containerClasses()}
          headerComponents={headerComponents}
          items={@state.suggestions}
          itemContent={itemContentFunc}
          itemKey={ (item) -> item.label || item.contact?.id || item.thread?.id}
          onSelect={@_onSelectSuggestion}
          />
      </div>
    </KeyCommandsRegion>

  _onFocusSearch: =>
    ReactDOM.findDOMNode(@refs.searchInput).focus()

  _containerClasses: =>
    classNames
      'focused': @state.focused
      'showing-query': @state.query?.length > 0
      'search-container': true
      'showing-suggestions': @state.suggestions?.length > 0

  _onValueChange: (event) =>
    SearchActions.queryChanged(event.target.value)
    if (event.target.value is '')
      @_onClearSearch()

  _onSelectSuggestion: (item) =>
    if item.thread?
      SearchActions.querySubmitted("\"#{item.thread.subject}\"")
    else
      SearchActions.querySubmitted(item.value)

  _onClearSearch: (event) =>
    SearchActions.querySubmitted("")

  _clearAndBlur: =>
    @_onClearSearch()
    ReactDOM.findDOMNode(@refs.searchInput)?.blur()

  _onFocus: =>
    @setState(focused: true)

  _onBlur: =>
    # Don't immediately hide the menu when the text input is blurred,
    # because the user might have clicked an item in the menu. Wait to
    # handle the touch event, then dismiss the menu.
    setTimeout =>
      SearchActions.searchBlurred()
      @setState(focused: false)
    , 150

  _doSearch: =>
    SearchActions.querySubmitted(@state.query)

  _onChange: =>
    @setState @_getStateFromStores()

  _getStateFromStores: =>
    query: SearchStore.query()
    suggestions: SearchStore.suggestions()
    isSearching: SearchStore.isSearching()

module.exports = SearchBar
