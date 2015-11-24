{shell} = require 'electron'
GithubStore = require './github-store'
{React} = require 'nylas-exports'
{RetinaImg, KeyCommandsRegion} = require 'nylas-component-kit'

###
The `ViewOnGithubButton` displays a button whenever there's a relevant
Github asset to link to.

When creating this React component the first consideration was when &
where we'd be rendered. The next consideration was what data we need to
display.

Unlike a traditional React application, N1 components have very few
guarantees on who will render them and where they will be rendered. In our
`lib/main.cjsx` file we registered this component with our
{ComponentRegistry} for the `"message:Toolbar"` role. That means that
whenever the "message:Toolbar" region gets rendered, we'll render
everything registered with that area. Other buttons, such as "Archive" and
the "Change Label" button are reigstered with that role, so we should
expect ourselves to showup alongside them.

The only data we need is a single relevant to Github. If we have one,
we'll open it up in a browser. If we don't have one, we'll hide the
component.

Getting that url takes a bit of message parsing. We need to retrieve a
message body then implement some kind of regex to find and parse out that
link.

We could have put all of that logic in this React Component, but that's
not what React components should be doing. In N1 a component's only job is
to display known data and be the first responders to user interaction.

We instead create a {GithubStore} to handle the fetching and preparation
of the data. See that file's documentation for more on how that works.

As far as this component is concerned, there will be an entity called
`GitHubStore` that will expose the correct `link`. That store will then
notify us when the `link` changes so we can update our state.

Once we know our `link` our `render` method can simply be a description of
how we want to display that link. In this case we're going to make a
simple button with a GitHub logo in it.

We'll also display nothing if there is no link.
###
class ViewOnGithubButton extends React.Component
  @displayName: "ViewOnGithubButton"
  @containerRequired: false


  #### React methods ####
  # The following methods are React methods that we override. See {React}
  # documentation for more info

  constructor: (@props) ->
    @state = @_getStateFromStores()

  # When components mount, it's very common to have them listen to a
  # `Store`. Since most of our React Components in N1 are registered into
  # {ComponentRegistry} regions instead of manually rendered top-down much
  # of our data is side-loaded from stores instead of passed in as props.
  componentDidMount: ->
    # The `listen` method of {NylasStore}s (which {GithubStore}
    # subclasses) returns an "unlistener" function. When the unlistener is
    # invoked (as it is in `componentWillUnmount`) the listener references
    # are cleaned up. Every time the `GithubStore` calls its `trigger`
    # method, the `_onStoreChanged` callback will be fired.
    @_unlisten = GithubStore.listen(@_onStoreChanged)

  componentWillUnmount: ->
    @_unlisten?()

  _keymapHandlers: ->
    'github:open': @_openLink

  render: ->
    return null unless @state.link
    <KeyCommandsRegion globalHandlers={@_keymapHandlers()}>
      <button className="btn btn-toolbar"
              onClick={@_openLink}
              title={"Visit Thread on GitHub"}>
        <RetinaImg
          mode={RetinaImg.Mode.ContentIsMask}
          url="nylas://N1-Message-View-on-Github/assets/github@2x.png" />
      </button>
    </KeyCommandsRegion>


  #### Super common N1 Component private methods ####

  # An extremely common pattern for all N1 components are the methods
  # `onStoreChanged` and `getStateFromStores`.
  #
  # Most N1 components listen to some source of data, which is usally a
  # Store. When the store notifies that something has changed, we need to
  # fetch the fresh data and updated our state.
  #
  # Note that when a Store updates it does not let us know what changed.
  # This is intentional! This forces us to fresh the full latest state
  # from the stores in a more declarative, easy-to-follow way. There are a
  # couple rare exceptions that are only used for performance
  # optimizations.

  # Note that we bind this method to the class instance's `this`. Any
  # method used as a callback must be bound. In Coffeescript we use the
  # fat arrow (`=>`)
  _onStoreChanged: =>
    @setState(@_getStateFromStores())

  # getStateFromStores fetches the data the view needs from the
  # appropriate data source (our GithubStore). We return a basic object
  # that can be passed directly into `setState`.
  _getStateFromStores: ->
    return {link: GithubStore.link()}


  #### Other utility "private" methods ####

  # This responds to user interaction. Since it's a callback we have to
  # bind it to the instances's `this` (Coffeescript fat arrow `=>`)
  #
  # In the case of this component we use the Electron `shell` module to
  # request the computer to open the default browser.
  #
  # In other very common cases, user interaction handlers may fire an
  # `Action` across the system for other Stores to respond to. They may
  # also queue a {Task} to eventually perform a mutating API POST or PUT
  # request.
  _openLink: =>
    shell.openExternal(@state.link) if @state.link

module.exports = ViewOnGithubButton
