# Publically exposed Nylas UI Components

{FormItem,
 GeneratedForm,
 GeneratedFieldset} = require ('../src/components/generated-form')

module.exports =
  # Models
  Menu: require '../src/components/menu'
  Spinner: require '../src/components/spinner'
  Popover: require '../src/components/popover'
  Flexbox: require '../src/components/flexbox'
  RetinaImg: require '../src/components/retina-img'
  ListTabular: require '../src/components/list-tabular'
  DraggableImg: require '../src/components/draggable-img'
  MultiselectList: require '../src/components/multiselect-list'
  MultiselectActionBar: require '../src/components/multiselect-action-bar'
  ResizableRegion: require '../src/components/resizable-region'
  ScrollRegion: require '../src/components/scroll-region'
  InjectedComponentSet: require '../src/components/injected-component-set'
  InjectedComponent: require '../src/components/injected-component'
  TokenizingTextField: require '../src/components/tokenizing-text-field'
  TimeoutTransitionGroup: require '../src/components/timeout-transition-group'
  FormItem: FormItem
  GeneratedForm: GeneratedForm
  GeneratedFieldset: GeneratedFieldset
  EventedIFrame: require '../src/components/evented-iframe'
