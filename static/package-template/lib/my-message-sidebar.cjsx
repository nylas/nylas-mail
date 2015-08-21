{Utils,
 React,
 FocusedContactsStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class MyMessageSidebar extends React.Component
  @displayName: 'MyMessageSidebar'

  # Providing container styles tells the app how to constrain
  # the column your component is being rendered in. The min and
  # max size of the column are chosen automatically based on
  # these values.
  @containerStyles:
    order: 1
    maxWidth: 300
    minWidth: 200
    flexShrink: 0

  # This sidebar component listens to the FocusedContactStore,
  # which gives us access to the Contact object of the currently
  # selected person in the conversation. If you wanted to take
  # the contact and fetch your own data, you'd want to create
  # your own store, so the flow of data would be:
  #
  # FocusedContactStore => Your Store => Your Component
  #
  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @unsubscribe = FocusedContactsStore.listen(@_onChange)

  componentWillUnmount: =>
    @unsubscribe()

  render: =>
    if @state.contact
      content = @_renderContent()
    else
      content = @_renderPlaceholder()

    <div className="my-message-sidebar">
      {content}
    </div>

  _renderContent: =>
    # Want to include images or other static assets in your components?
    # Reference them using the nylas:// URL scheme:
    #
    # <RetinaImg
    #    url="nylas://<<package.name>>/assets/checkmark_template@2x.png"
    #    mode={RetinaImg.Mode.ContentIsMask}/>
    #
    <div className="header">
      <h1>{@state.contact.displayName()} is the focused contact.</h1>
    </div>

  _renderPlaceholder: =>
    <div> No Data Available </div>

  _onChange: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    contact: FocusedContactsStore.focusedContact()


module.exports = MyMessageSidebar
