# Publically exposed Nylas UI Components
class NylasComponentKit
  @load = (prop, path) ->
    Object.defineProperty @prototype, prop,
      get: -> require "../src/components/#{path}"

  @loadFrom = (prop, path) ->
    Object.defineProperty @prototype, prop,
      get: ->
        exported = require "../src/components/#{path}"
        return exported[prop]

  @load "Menu", 'menu'
  @load "DropZone", 'drop-zone'
  @load "Spinner", 'spinner'
  @load "Popover", 'popover'
  @load "Flexbox", 'flexbox'
  @load "RetinaImg", 'retina-img'
  @load "ListTabular", 'list-tabular'
  @load "DraggableImg", 'draggable-img'
  @load "EventedIFrame", 'evented-iframe'
  @load "ButtonDropdown", 'button-dropdown'
  @load "MultiselectList", 'multiselect-list'
  @load "InjectedComponent", 'injected-component'
  @load "TokenizingTextField", 'tokenizing-text-field'
  @load "MultiselectActionBar", 'multiselect-action-bar'
  @load "InjectedComponentSet", 'injected-component-set'
  @load "TimeoutTransitionGroup", 'timeout-transition-group'
  @load "ConfigPropContainer", "config-prop-container"

  @load "ScrollRegion", 'scroll-region'
  @load "ResizableRegion", 'resizable-region'
  @load "FocusTrackingRegion", 'focus-tracking-region'

  @loadFrom "MailLabel", "mail-label"
  @loadFrom "LabelColorizer", "mail-label"
  @load "MailImportantIcon", 'mail-important-icon'

  @loadFrom "FormItem", "generated-form"
  @loadFrom "GeneratedForm", "generated-form"
  @loadFrom "GeneratedFieldset", "generated-form"

module.exports = new NylasComponentKit()
