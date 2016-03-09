_ = require 'underscore'
React = require 'react'

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
    thread: React.PropTypes.object
    items: React.PropTypes.array

  @contextTypes:
    sheetDepth: React.PropTypes.number

  constructor: (@props) ->
    @_threads = @_getThreads(@props)
    @_account = AccountStore.accountForItems(@_threads)

  # If the threads we're picking categories for change, (like when they
  # get their categories updated), we expect our parents to pass us new
  # props. We don't listen to the DatabaseStore ourselves.
  componentWillReceiveProps: (nextProps) ->
    @_threads = @_getThreads(nextProps)
    @_account = AccountStore.accountForItems(@_threads)

  _getThreads: (props = @props) =>
    if props.items then return (props.items ? [])
    else if props.thread then return [props.thread]
    else return []

  _keymapHandlers: ->
    "application:change-category": @_onOpenCategoryPopover

  _onOpenCategoryPopover: =>
    return unless @_threads.length > 0
    return unless @context.sheetDepth is WorkspaceStore.sheetStack().length - 1
    buttonRect = React.findDOMNode(@refs.button).getBoundingClientRect()
    Actions.openPopover(
      <CategoryPickerPopover
        threads={@_threads}
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
          ref="button"
          title={tooltip}
          onClick={@_onOpenCategoryPopover}
          className={btnClasses} >
          <RetinaImg name={img} mode={RetinaImg.Mode.ContentIsMask}/>
        </button>
      </KeyCommandsRegion>
    )


module.exports = CategoryPicker
