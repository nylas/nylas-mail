React              = require 'react'
_                  = require 'underscore'
_str               = require 'underscore.string'
AccountSidebarItem = require './account-sidebar-item'

{RetinaImg,
 DisclosureTriangle} = require 'nylas-component-kit'

class AccountSidebarSection extends React.Component
  @displayName: "AccountSidebarSection"

  @propTypes: {
    section: React.PropTypes.object.isRequired
    collapsed: React.PropTypes.object.isRequired
    selected: React.PropTypes.object.isRequired
    onToggleCollapsed: React.PropTypes.func.isRequired
  }

  constructor: (@props) ->
    @state = {showCreateInput: false}

  render: ->
    section     = @props.section
    showInput   = @state.showCreateInput
    allowCreate = section.createItem?

    <section>
      <div className="heading">{section.label}</div>
      {@_createItemButton(section) if allowCreate}
      {@_createItemInput(section) if allowCreate and showInput}
      {@_itemComponents(section.items)}
    </section>

  _createItemButton: ({label}) ->
    <div
      className="add-item-button"
      onClick={@_onCreateButtonClicked.bind(@, label)}>
      <RetinaImg
        url="nylas://account-sidebar/assets/icon-sidebar-addcategory@2x.png"
        style={height: 14, width: 14}
        mode={RetinaImg.Mode.ContentIsMask} />
    </div>

  _createItemInput: (section) ->
    label = _str.decapitalize section.label[...-1]
    placeholder = "Create new #{label}"
    <span className="item-container">
      <div className="item add-item-container">
        <DisclosureTriangle collapsed={false} visible={false} />
        <div className="icon">
          <RetinaImg
            name="#{section.iconName}"
            fallback="folder.png"
            mode={RetinaImg.Mode.ContentIsMask} />
        </div>
        <input
          type="text"
          tabIndex="1"
          className="input-bordered add-item-input"
          autoFocus={true}
          onKeyDown={_.partial @_onInputKeyDown, _, section}
          onBlur={ => @setState(showCreateInput: false) }
          placeholder={placeholder}/>
      </div>
    </span>

  _itemComponents: (items) =>
    components = []

    items.forEach (item) =>
      components.push(
        <AccountSidebarItem
          key={item.id}
          item={item}
          collapsed={@props.collapsed[item.id]}
          selected={@props.selected}
          onDestroyItem={@props.section.destroyItem}
          onToggleCollapsed={@props.onToggleCollapsed} />
      )

      if item.children.length and not @props.collapsed[item.id]
        components.push(
          <section key={"#{item.id}-children"}>
            {@_itemComponents(item.children)}
          </section>
        )

    components

  _onCreateButtonClicked: (sectionLabel) =>
    @setState(showCreateInput: not @state.showCreateInput)

  _onInputKeyDown: (event, section) =>
    if event.key is 'Escape'
      @setState(showCreateInput: false)
    if event.key in ['Enter', 'Return']
      @props.section.createItem?(event.target.value)
      @setState(showCreateInput: false)

module.exports = AccountSidebarSection
