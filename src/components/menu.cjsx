React = require 'react/addons'
classNames = require 'classnames'
_ = require 'underscore'
{DOMUtils} = require 'nylas-exports'
{CompositeDisposable} = require 'event-kit'

###
Public: `MenuItem` components can be provided to the {Menu} by the `itemContent` function.
MenuItem's props allow you to display dividers as well as standard items.

Section: Component Kit
###
class MenuItem extends React.Component
  @displayName = 'MenuItem'

  ###
  Public: React `props` supported by MenuItem:

   - `divider` (optional) Pass a {String} to render the menu item as a section divider.
   - `key` (optional)
   - `selected` (optional)
   - `checked` (optional)
  ###
  @propTypes:
    divider: React.PropTypes.string
    key: React.PropTypes.string
    selected: React.PropTypes.bool
    checked: React.PropTypes.bool

  render: =>
    if @props.divider?
      <div className="item divider">{@props.divider}</div>
    else
      className = classNames
        "item": true
        "selected": @props.selected
        "checked": @props.checked
      <div className={className} key={@props.key} onMouseDown={@props.onMouseDown}>{@props.content}</div>

###
Public: React component for a {Menu} item that displays a name and email address.

Section: Component Kit
###
class MenuNameEmailItem extends React.Component
  @displayName: 'MenuNameEmailItem'

  ###
  Public: React `props` supported by MenuNameEmailItem:

   - `name` (optional) The {String} name to be displayed.
   - `email` (optional) The {String} email address to be displayed.
  ###
  @propTypes:
    name: React.PropTypes.string
    email: React.PropTypes.string

  render: =>
    if @props.name?.length > 0 and @props.name isnt @props.email
      <span>
        <span className="primary">{@props.name}</span>
        <span className="secondary">{"(#{@props.email})"}</span>
      </span>
    else
      <span className="primary">{@props.email}</span>

###
Public: React component for multi-section Menus with key binding

The Menu component allows you to display a list of items. Menu takes care of
several important things, ensuring that your menu is consistent with the rest
of the Edgehill application and offers a near-native experience:

- Keyboard Interaction with the Up and Down arrow keys, Enter to select
- Maintaining selection across content changes
- Highlighted state

Menus are often, but not always, used in conjunction with {Popover} to display
a floating "popup" menu. See `template-picker.cjsx` for an example.

The Menu also exposes "header" and "footer" regions you can fill with arbitrary
components by providing the `headerComponents` and `footerComponents` props.
These items are nested within `.header-container`. and `.footer-container`,
and you can customize their appearance by providing CSS selectors scoped to your
component's Menu instance:

```css
.template-picker .menu .header-container {
  height: 100px;
}
```

Section: Component Kit
###
class Menu extends React.Component
  @displayName: 'Menu'

  ###
  Public: React `props` supported by Menu:

   - `className` (optional) The {String} class name applied to the Menu

   - `itemContent` A {Function} that returns a {MenuItem}, {String}, or
     React component for the given `item`.

     If you return a {MenuItem}, your item is injected into the list directly.

     If you return a string or React component, the result is placed within a
     {MenuItem}, resulting in the following DOM:
     `<div className="item [selected]">{your content}</div>`.

     To create dividers and other special menu items, return an instance of:

     <Menu.Item divider="Label">

   - `itemKey` A {Function} that returns a unique string key for the given `item`.
     Keys are important for efficient React rendering when `items` is changed, and a
     key function is required.

   - `itemChecked` A {Function} that returns true if the given item should be shown
     with a checkmark. If you don't provide an implementation for `itemChecked`, no
     checkmarks are ever shown.

   - `items` An {Array} of arbitrary objects the menu should display.

   - `onSelect` A {Function} called with the selected item when the user clicks
     an item in the menu or confirms their selection with the Enter key.

   - `defaultSelectedIndex` The index of the item first selected if there
   was no other previous index. Defaults to 0. Set to -1 if you want
   nothing selected.

  ###
  @propTypes:
    className: React.PropTypes.string,
    footerComponents: React.PropTypes.arrayOf(React.PropTypes.element),
    headerComponents: React.PropTypes.arrayOf(React.PropTypes.element),
    itemContent: React.PropTypes.func.isRequired,
    itemKey: React.PropTypes.func.isRequired,
    itemChecked: React.PropTypes.func,

    items: React.PropTypes.array.isRequired

    onSelect: React.PropTypes.func.isRequired,

    defaultSelectedIndex: React.PropTypes.number

  constructor: (@props) ->
    @state =
      selectedIndex: @props.defaultSelectedIndex ? 0

  # Public: Returns the currently selected item.
  #
  getSelectedItem: =>
    @props.items[@state.selectedIndex]

  # Public: Set the currently selected item. Pass
  # null to remove the selection
  #
  setSelectedItem: (item) =>
    @setState selectedIndex: @props.items.indexOf(item)

  componentWillReceiveProps: (newProps) =>
    # Attempt to preserve selection across props.items changes by
    # finding an item in the new list with a key matching the old
    # selected item's key
    if @state.selectedIndex >= 0
      selection = @props.items[@state.selectedIndex]
      newSelectionIndex = 0
    else
      newSelectionIndex = newProps.defaultSelectedIndex ? -1

    if selection?
      selectionKey = @props.itemKey(selection)
      newSelection = _.find newProps.items, (item) => @props.itemKey(item) is selectionKey
      newSelectionIndex = newProps.items.indexOf(newSelection) if newSelection?

    @setState
      selectedIndex: newSelectionIndex

  componentDidUpdate: =>
    item = React.findDOMNode(@).querySelector(".selected")
    container = React.findDOMNode(@).querySelector(".content-container")
    adjustment = DOMUtils.scrollAdjustmentToMakeNodeVisibleInContainer(item, container)
    if adjustment isnt 0
      container.scrollTop += adjustment

  render: =>
    hc = @props.headerComponents ? []
    if hc.length is 0 then hc = <span></span>
    fc = @props.footerComponents ? []
    if fc.length is 0 then fc = <span></span>
    <div onKeyDown={@_onKeyDown}
         className={"native-key-bindings menu " + @props.className}
         tabIndex="-1">
      <div className="header-container">
        {hc}
      </div>
      {@_contentContainer()}
      <div className="footer-container">
        {fc}
      </div>
    </div>

  _onKeyDown: (event) =>
    if event.key is "Enter"
      @_onEnter()
    else if event.key is "ArrowUp" or (event.key is "Tab" and event.shiftKey)
      @_onShiftSelectedIndex(-1)
      event.preventDefault()
    else if event.key is "ArrowDown" or event.key is "Tab"
      @_onShiftSelectedIndex(1)
      event.preventDefault()

    return

  _contentContainer: =>
    items = @props.items.map(@_itemComponentForItem) ? []
    contentClass = classNames
      'content-container': true
      'empty': items.length is 0

    <div className={contentClass}>
      {items}
    </div>

  _itemComponentForItem: (item, i) =>
    content = @props.itemContent(item)

    if React.isValidElement(content) and content.type is MenuItem
      return content

    onMouseDown = (event) =>
      event.preventDefault()
      @props.onSelect(item) if @props.onSelect

    <MenuItem onMouseDown={onMouseDown}
              key={@props.itemKey(item)}
              checked={@props.itemChecked?(item)}
              content={content}
              selected={@state.selectedIndex is i} />

  _onShiftSelectedIndex: (delta) =>
    return if @props.items.length is 0

    index = @state.selectedIndex + delta

    isDivider = true
    while isDivider
      item = @props.items[index]
      break unless item
      if @props.itemContent(item).props?.divider
        if delta > 0 then index += 1
        else if delta < 0 then index -= 1
      else isDivider = false

    index = Math.max(0, Math.min(@props.items.length-1, index))

    # Update the selected index
    @setState selectedIndex: index

  _onEnter: =>
    item = @props.items[@state.selectedIndex]
    @props.onSelect(item) if item?


Menu.Item = MenuItem
Menu.NameEmailItem = MenuNameEmailItem

module.exports = Menu
