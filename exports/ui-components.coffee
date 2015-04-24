# All Inbox Globals go here.

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
  MultiselectList: require '../src/components/multiselect-list'
  MultiselectActionBar: require '../src/components/multiselect-action-bar'
  ResizableRegion: require '../src/components/resizable-region'
  RegisteredRegion: require '../src/components/registered-region'
  TokenizingTextField: require '../src/components/tokenizing-text-field'
  FormItem: FormItem
  GeneratedForm: GeneratedForm
  GeneratedFieldset: GeneratedFieldset
  EventedIFrame: require '../src/components/evented-iframe'
