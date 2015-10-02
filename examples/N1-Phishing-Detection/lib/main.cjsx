# # Phishing Detection
#
# This is a simple package to notify N1 users if an email is a potential
# phishing scam.

# You can access N1 dependencies by requiring 'nylas-exports'
{React,
 # The ComponentRegistry manages all React components in N1.
 ComponentRegistry,
 # A `Store` is a Flux component which contains all business logic and data
 # models to be consumed by React components to render markup.
 MessageStore} = require 'nylas-exports'

# Notice that this file is `main.cjsx` rather than `main.coffee`. We use the
# `.cjsx` filetype because we use the CJSX DSL to describe markup for React to
# render. Without the CJSX, we could just name this file `main.coffee` instead.
class PhishingIndicator extends React.Component

  # Adding a @displayName to a React component helps for debugging.
  @displayName: 'PhishingIndicator'

  # @propTypes is an object which validates the datatypes of properties that
  # this React component can receive.
  @propTypes:
    thread: React.PropTypes.object.isRequired

  # A React component's `render` method returns a virtual DOM element described
  # in CJSX. `render` is deterministic: with the same input, it will always
  # render the same output. Here, the input is provided by @isPhishingAttempt.
  # `@state` and `@props` are popular inputs as well.
  render: =>

    # Our inputs for the virtual DOM to render come from @isPhishingAttempt.
    [from, reply_to] = @isPhishingAttempt()

    # We add some more application logic to decide how to render.
    if from isnt null and reply_to isnt null
      <div className="phishingIndicator">
        <b>This message looks suspicious!</b>
        <p>It originates from {from} but replies will go to {reply_to}.</p>
      </div>

    # If you don't want a React component to render anything at all, then your
    # `render` method should return `null` or `undefined`.
    else
      null

  isPhishingAttempt: =>

    # In this package, the MessageStore is the source of our data which will be
    # the input for the `render` function. @isPhishingAttempt is performing some
    # domain-specific application logic to prepare the data for `render`.
    message = MessageStore.items()[0]

    # This package's strategy to ascertain whether or not the email is a
    # phishing attempt boils down to checking the `replyTo` attributes on
    # `Message` models from `MessageStore`.
    if message.replyTo? and message.replyTo.length != 0

      # The `from` and `replyTo` attributes on `Message` models both refer to
      # arrays of `Contact` models, which in turn have `email` attributes.
      from = message.from[0].email
      reply_to = message.replyTo[0].email

      # This is our core logic for our whole package! If the `from` and
      # `replyTo` emails are different, then we want to show a phishing warning.
      if reply_to isnt from
          return [from, reply_to]

    return [null, null];

module.exports =

  # Activate is called when the package is loaded. If your package previously
  # saved state using `serialize` it is provided.
  activate: (@state) ->

    # This is a good time to tell the `ComponentRegistry` to insert our
    # React component into the `'MessageListHeaders'` part of the application.
    ComponentRegistry.register PhishingIndicator,
      role: 'MessageListHeaders'

  # Serialize is called when your package is about to be unmounted.
  # You can return a state object that will be passed back to your package
  # when it is re-activated.
  serialize: ->

  # This **optional** method is called when the window is shutting down,
  # or when your package is being updated or disabled. If your package is
  # watching any files, holding external resources, providing commands or
  # subscribing to events, release them here.
  deactivate: ->
    ComponentRegistry.unregister(PhishingIndicator)
