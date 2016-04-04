_ = require 'underscore'
React = require 'react'
ReactDOM = require 'react-dom'

{Actions,
 AccountStore,
 WorkspaceStore} = require 'nylas-exports'

{RetinaImg,
 KeyCommandsRegion} = require 'nylas-component-kit'

CategoryPickerPopover = require './category-picker-popover'


# This changes the category on one or more threads.
class CategoryPicker extends React.Component
  @displayName: "CategoryPicker"

  @containerRequired: false

  @propTypes:
    items: React.PropTypes.array

  @contextTypes:
    sheetDepth: React.PropTypes.number

  constructor: (@props) ->
    @_account = AccountStore.accountForItems(@props.items)

  # If the threads we're picking categories for change, (like when they
  # get their categories updated), we expect our parents to pass us new
  # props. We don't listen to the DatabaseStore ourselves.
  componentWillReceiveProps: (nextProps) ->
    @_account = AccountStore.accountForItems(nextProps.items)

  _keymapHandlers: ->
    "application:change-category": @_onOpenCategoryPopover

  _onOpenCategoryPopover: =>
    return unless @props.items.length > 0
    return unless @context.sheetDepth is WorkspaceStore.sheetStack().length - 1
    buttonRect = ReactDOM.findDOMNode(@refs.button).getBoundingClientRect()
    Actions.openPopover(
      <CategoryPickerPopover
        threads={@props.items}
        account={@_account} />,
      {originRect: buttonRect, direction: 'down'}
    )
    return

  render: =>
    return <span /> unless @_account
    btnClasses = "btn btn-toolbar btn-category-picker"
    img = ""
    tooltip = ""
    if @_account.usesLabels()
      img = "toolbar-tag.png"
      tooltip = "Apply Labels"
    else
      img = "toolbar-movetofolder.png"
      tooltip = "Move to Folder"

    return (
      <KeyCommandsRegion style={order: -103} globalHandlers={@_keymapHandlers()}>
        <button
          tabIndex={-1}
          ref="button"
          title={tooltip}
          onClick={@_onOpenCategoryPopover}
          className={btnClasses} >
          <RetinaImg name={img} mode={RetinaImg.Mode.ContentIsMask}/>
        </button>
      </KeyCommandsRegion>
    )


module.exports = CategoryPicker
