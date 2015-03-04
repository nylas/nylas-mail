React = require 'react/addons'
_ = require 'underscore-plus'
{CompositeDisposable} = require 'event-kit'

###
The Menu component allows you to display a list of items. Menu takes care of
several important things, ensuring that your menu is consistent with the rest
of the Edgehill application and offers a near-native experience:

- Keyboard Interaction with the Up and Down arrow keys, Enter to select
- Maintaining selection across content changes
- Highlighted state

Menus are often, but not always, used in conjunction with `Popover` to display
a floating "popup" menu. See `template-picker.cjsx` for an example.

Populating the Menu
-------------------

When you render a Menu component, you need to provide three important props:

`items`:
  An array of arbitrary objects the menu should display.

`itemContent`:
  A function that returns a MenuItem, string, or React component for the given
  `item`.

  If you return a MenuItem, your item is injected into the list directly.

  If you return a string or React component, the result is placed within a
  MenuItem, resulting in the following DOM:
  `<div className="item [selected]">{your content}</div>`.

  To create dividers and other special menu items, return an instance of:
  <Menu.Item divider content="Label">

`itemKey`:
  A function that returns a unique string key for the given `item`. Keys are
  important for efficient React rendering when `items` is changed, and a
  key function is required.

The Menu also exposes "header" and "footer" regions you can fill with arbitrary
components by providing the `headerComponents` and `footerComponents` props.
These items are nested within `.header-container`. and `.footer-container`,
and you can customize their appearance by providing CSS selectors scoped to your
component's Menu instance:

```
.template-picker .menu .header-container {
  height: 100px;
}
```

Events
------

`onSelect`:
  Called with the selected item when the user clicks an item in the menu
  or confirms their selection with the Enter key.

###


MenuItem = React.createClass
  render: ->
    if @props.divider
      <div className="divider">{@props.divider}</div>
    else
      className = "item"
      className += " selected" if @props.selected
      <div className={className} key={@props.key} onMouseDown={@props.onMouseDown}>{@props.content}</div>


Menu = React.createClass

  propTypes:
    className: React.PropTypes.string,
    footerComponents: React.PropTypes.arrayOf(React.PropTypes.element),
    headerComponents: React.PropTypes.arrayOf(React.PropTypes.element),
    itemContent: React.PropTypes.func.isRequired,
    itemKey: React.PropTypes.func.isRequired,
    items: React.PropTypes.arrayOf(React.PropTypes.object)

    onSelect: React.PropTypes.func.isRequired,

  getInitialState: ->
    selectedIndex: 0

  getSelectedItem: ->
    @props.items[@state.selectedIndex]

  componentDidMount: ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add atom.commands.add '.menu', {
      'menu:move-up': => @_onShiftSelectedIndex(-1)
      'menu:move-down': => @_onShiftSelectedIndex(1)
      'menu:enter': => @_onEnter()
    }

  componentWillReceiveProps: (newProps) ->
    # Attempt to preserve selection across props.items changes by
    # finding an item in the new list with a key matching the old
    # selected item's key
    selection = @props.items[@state.selectedIndex]

    if selection?
      selectionKey = @props.itemKey(selection)
      newSelection = _.find newProps.items, (item) => @props.itemKey(item) is selectionKey

      newSelectionIndex = -1
      newSelectionIndex = newProps.items.indexOf(newSelection) if newSelection?

      @setState
        selectedIndex: newSelectionIndex

  componentWillUnmount: ->
    @subscriptions?.dispose()

  render: ->
    hc = @props.headerComponents ? []
    if hc.length is 0 then hc = <span></span>
    fc = @props.footerComponents ? []
    if fc.length is 0 then fc = <span></span>
    <div className={"menu " + @props.className}>
      <div className="header-container">
        {hc}
      </div>
      {@_contentContainer()}
      <div className="footer-container">
        {fc}
      </div>
    </div>

  _contentContainer: ->
    items = @props.items.map(@_itemComponentForItem) ? []
    if items.length is 0
      <span></span>
    else
      <div className="content-container">
        {items}
      </div>

  _itemComponentForItem: (item, i) ->
    content = @props.itemContent(item)
    return content if content.type is MenuItem.type

    onMouseDown = (event) =>
      event.preventDefault()
      @props.onSelect(item) if @props.onSelect

    <MenuItem onMouseDown={onMouseDown}
              key={@props.itemKey(item)}
              content={content}
              selected={@state.selectedIndex is i} />

  _onShiftSelectedIndex: (delta) ->
    return if @props.items.length is 0
    index = @state.selectedIndex + delta
    index = Math.max(0, Math.min(@props.items.length-1, index))

    # Update the selected index
    @setState
      selectedIndex: index

    # Fire the shift method again to move selection past the divider
    # if the new selected item is a divider.
    itemContent = @props.itemContent(@props.items[index])
    isDivider = itemContent.props?.divider
    @_onShiftSelectedIndex(delta) if isDivider

  _onEnter: ->
    item = @props.items[@state.selectedIndex]
    @props.onSelect(item) if item?


Menu.Item = MenuItem

module.exports = Menu
