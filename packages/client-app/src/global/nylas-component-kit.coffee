# Publically exposed Nylas UI Components
class NylasComponentKit

  @default = (requireValue) -> requireValue.default ? requireValue

  @load = (prop, path) ->
    Object.defineProperty @prototype, prop,
      get: ->
        NylasComponentKit.default(require "../components/#{path}")

  # We use require to load the component immediately (instead of lazy loading)
  # to improve visible latency,
  # Sometimes a component won't be loaded until the user performs an action
  # (e.g. opening a popover), so we don't want to wait until that happens to load the
  # component. In our example, the popover would take a long time to open the first time
  # if it was lazy loaded
  @require = (prop, path) ->
    exported = NylasComponentKit.default(require "../components/#{path}")
    Object.defineProperty @prototype, prop,
      get: -> exported

  @requireFrom = (prop, path) ->
    exported = require "../components/#{path}"
    Object.defineProperty @prototype, prop,
      get: -> exported[prop]

  @loadFrom = (prop, path) ->
    Object.defineProperty @prototype, prop,
      get: ->
        exported = require "../components/#{path}"
        return exported[prop]

  @loadDeprecated = (prop, path, {instead} = {}) ->
    {deprecate} = require '../deprecate-utils'
    Object.defineProperty @prototype, prop,
      get: deprecate prop, instead, @, ->
        exported = NylasComponentKit.default(require "../components/#{path}")
        return exported
      enumerable: true

  @load "Menu", 'menu'
  @load "DropZone", 'drop-zone'
  @load "Spinner", 'spinner'
  @load "Switch", 'switch'
  @loadDeprecated "Popover", 'popover', instead: 'Actions.openPopover'
  @load "FixedPopover", 'fixed-popover'
  @require "DatePickerPopover", 'date-picker-popover'
  @load "Modal", 'modal'
  @load "Webview", 'webview'
  @load "FeatureUsedUpModal", 'feature-used-up-modal'
  @load "BillingModal", 'billing-modal'
  @load "OpenIdentityPageButton", 'open-identity-page-button'
  @load "Flexbox", 'flexbox'
  @load "RetinaImg", 'retina-img'
  @load "SwipeContainer", 'swipe-container'
  @load "FluxContainer", 'flux-container'
  @load "FocusContainer", 'focus-container'
  @load "SyncingListState", 'syncing-list-state'
  @load "EmptyListState", 'empty-list-state'
  @load "ListTabular", 'list-tabular'
  @load "Notification", 'notification'
  @load "NylasCalendar", 'nylas-calendar/nylas-calendar'
  @load "MiniMonthView", 'nylas-calendar/mini-month-view'
  @load "CalendarEventPopover", 'nylas-calendar/calendar-event-popover'
  @load "EventedIFrame", 'evented-iframe'
  @load "ButtonDropdown", 'button-dropdown'
  @load "Contenteditable", 'contenteditable/contenteditable'
  @load "MultiselectList", 'multiselect-list'
  @load "BoldedSearchResult", 'bolded-search-result'
  @load "MultiselectDropdown", "multiselect-dropdown"
  @load "KeyCommandsRegion", 'key-commands-region'
  @load "TabGroupRegion", 'tab-group-region'
  @load "InjectedComponent", 'injected-component'
  @load "TokenizingTextField", 'tokenizing-text-field'
  @load "ParticipantsTextField", 'participants-text-field'
  @loadDeprecated "MultiselectActionBar", 'multiselect-action-bar', instead: 'MultiselectToolbar'
  @load "MultiselectToolbar", 'multiselect-toolbar'
  @load "InjectedComponentSet", 'injected-component-set'
  @load "MetadataComposerToggleButton", 'metadata-composer-toggle-button'
  @load "ConfigPropContainer", "config-prop-container"
  @load "DisclosureTriangle", "disclosure-triangle"
  @load "EditableList", "editable-list"
  @load "OutlineViewItem", "outline-view-item"
  @load "OutlineView", "outline-view"
  @load "DateInput", "date-input"
  @load "DatePicker", "date-picker"
  @load "TimePicker", "time-picker"
  @load "Table", "table/table"
  @loadFrom "TableRow", "table/table"
  @loadFrom "TableCell", "table/table"
  @load "SelectableTable", "selectable-table"
  @loadFrom "SelectableTableRow", "selectable-table"
  @loadFrom "SelectableTableCell", "selectable-table"
  @load "EditableTable", "editable-table"
  @loadFrom "EditableTableCell", "editable-table"
  @load "Toast", "toast"
  @load "UndoToast", "undo-toast"
  @load "LazyRenderedList", "lazy-rendered-list"
  @load "OverlaidComponents", "overlaid-components/overlaid-components"
  @load "OverlaidComposerExtension", "overlaid-components/overlaid-composer-extension"
  @load "OAuthSignInPage", "oauth-signin-page"
  @requireFrom "AttachmentItem", "attachment-items"
  @requireFrom "ImageAttachmentItem", "attachment-items"
  @load "CodeSnippet", "code-snippet"

  @load "ScrollRegion", 'scroll-region'
  @load "ResizableRegion", 'resizable-region'

  @loadFrom "MailLabel", "mail-label"
  @loadFrom "LabelColorizer", "mail-label"
  @load "MailLabelSet", "mail-label-set"
  @load "MailImportantIcon", 'mail-important-icon'

  @loadFrom "FormItem", "generated-form"
  @loadFrom "GeneratedForm", "generated-form"
  @loadFrom "GeneratedFieldset", "generated-form"

  @load "ScenarioEditor", 'scenario-editor'
  @load "NewsletterSignup", 'newsletter-signup'

  @load "SearchBar", 'search-bar'

  # Higher order components
  @load "ListensToObservable", 'decorators/listens-to-observable'
  @load "ListensToFluxStore", 'decorators/listens-to-flux-store'
  @load "ListensToMovementKeys", 'decorators/listens-to-movement-keys'
  @load "HasTutorialTip", 'decorators/has-tutorial-tip'

module.exports = new NylasComponentKit()
