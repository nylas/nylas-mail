_ = require 'underscore'

{Actions,
 React, ReactDOM, PropTypes,
 AccountStore,
 WorkspaceStore} = require 'mailspring-exports'

{RetinaImg,
 KeyCommandsRegion} = require 'mailspring-component-kit'

MovePickerPopover = require('./move-picker-popover').default


# This sets the folder / label on one or more threads.
class MovePicker extends React.Component
  @displayName: "MovePicker"

  @containerRequired: false

  @propTypes:
    items: PropTypes.array

  @contextTypes:
    sheetDepth: PropTypes.number

  constructor: (@props) ->
    @_account = AccountStore.accountForItems(@props.items)

  # If the threads we're picking categories for change, (like when they
  # get their categories updated), we expect our parents to pass us new
  # props. We don't listen to the DatabaseStore ourselves.
  componentWillReceiveProps: (nextProps) ->
    @_account = AccountStore.accountForItems(nextProps.items)

  _keymapHandlers: ->
    "core:change-folders": @_onOpenCategoryPopover

  _onOpenCategoryPopover: =>
    return unless @props.items.length > 0
    return unless @context.sheetDepth is WorkspaceStore.sheetStack().length - 1
    buttonRect = this._buttonEl.getBoundingClientRect()
    Actions.openPopover(
      <MovePickerPopover
        threads={@props.items}
        account={@_account} />,
      {originRect: buttonRect, direction: 'down'}
    )
    return

  render: =>
    return <span /> unless @_account
    btnClasses = "btn btn-toolbar btn-category-picker"

    return (
      <KeyCommandsRegion
        style={order: -103}
        globalHandlers={@_keymapHandlers()}
        globalMenuItems={[
          {
            "label": "Thread",
            "submenu": [{ "label": "Move to Folder...", "command": "core:change-folders", "position": "endof=thread-actions" }]
          }
        ]}
        >
        <button
          tabIndex={-1}
          ref={(el) => this._buttonEl = el}
          title={"Move to Folder"}
          onClick={@_onOpenCategoryPopover}
          className={btnClasses} >
          <RetinaImg name={"toolbar-movetofolder.png"} mode={RetinaImg.Mode.ContentIsMask}/>
        </button>
      </KeyCommandsRegion>
    )


module.exports = MovePicker
