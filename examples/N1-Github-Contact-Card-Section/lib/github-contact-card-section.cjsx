_ = require 'underscore-plus'
GithubUserStore = require "./github-user-store"
{React} = require 'nylas-exports'

# Small React component that renders a single Github repository
class GithubRepo extends React.Component
  @displayName: 'GithubRepo'
  @propTypes:
    # This component takes a `repo` object as a prop. Listing props is optional
    # but enables nice React warnings when our expectations aren't met
    repo: React.PropTypes.object.isRequired

  render: =>
    <div className="repo">
      <div className="stars">{@props.repo.stargazers_count}</div>
      <a href={@props.repo.html_url}>{@props.repo.full_name}</a>
    </div>

# Small React component that renders the user's Github profile.
class GithubProfile extends React.Component
  @displayName: 'GithubProfile'
  @propTypes:
    # This component takes a `profile` object as a prop. Listing props is optional
    # but enables nice React warnings when our expectations aren't met.
    profile: React.PropTypes.object.isRequired

  render: =>
    # Transform the profile's array of repos into an array of React <GithubRepo> elements
    repoElements = _.map @props.profile.repos, (repo) ->
      <GithubRepo key={repo.id} repo={repo} />

    # Remember - this looks like HTML, but it's actually CJSX, which is converted into
    # Coffeescript at transpile-time. We're actually creating a nested tree of Javascript
    # objects here that *represent* the DOM we want.
    <div className="profile">
      <img className="logo" src="nylas://N1-Github-Contact-Card-Section/assets/github.png"/>
      <a href={@props.profile.html_url}>{@props.profile.login}</a>
      <div>{repoElements}</div>
    </div>

module.exports =
class GithubContactCardSection extends React.Component
  @displayName: 'GithubContactCardSection'

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    # When our component mounts, start listening to the GithubUserStore.
    # When the store `triggers`, our `_onChange` method will fire and allow
    # us to replace our state.
    @unsubscribe = GithubUserStore.listen @_onChange

  componentWillUnmount: =>
    @unsubscribe()

  render: =>
    <div className="sidebar-github-profile">
      <h2>Github</h2>
      {@_renderInner()}
    </div>

  _renderInner: =>
    # Handle various loading states by returning early
    return <div>Loading...</div> if @state.loading
    return <div>No Matching Profile</div> if not @state.profile
    <GithubProfile profile={@state.profile} />

  # The data vended by the GithubUserStore has changed. Calling `setState:`
  # will cause React to re-render our view to reflect the new values.
  _onChange: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    profile: GithubUserStore.profileForFocusedContact()
    loading: GithubUserStore.loading()
