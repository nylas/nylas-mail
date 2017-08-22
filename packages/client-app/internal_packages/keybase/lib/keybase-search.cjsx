{Utils,
 React,
 ReactDOM,
 Actions,
 RegExpUtils,
 IdentityStore,
 AccountStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'
EmailPopover = require './email-popover'
PGPKeyStore = require './pgp-key-store'
KeybaseUser = require '../lib/keybase-user'
Identity = require './identity'
kb = require './keybase'
_ = require 'underscore'

module.exports =
class KeybaseSearch extends React.Component
  @displayName: 'KeybaseSearch'

  @propTypes:
    initialSearch: React.PropTypes.string
    # importFunc: a alternate function to execute when the "import" button is
    # clicked instead of the "please specify an email" popover
    importFunc: React.PropTypes.func
    # TODO consider just passing in a pre-specified email instead of a func?
    inPreferences: React.PropTypes.bool

  @defaultProps:
    initialSearch: ""
    importFunc: null
    inPreferences: false

  constructor: (props) ->
    super(props)
    @state = {
      query: props.initialSearch
      results: []
      loading: false
      searchedByEmail: false
    }

    @debouncedSearch =  _.debounce(@_search, 300)

  componentDidMount: ->
    @_search()

  componentWillReceiveProps: (props) ->
    @setState({query: props.initialSearch})

  _search: ->
    oldquery = @state.query
    if @state.query != "" and @state.loading == false
      @setState({loading: true})
      kb.autocomplete(@state.query, (error, profiles) =>
        if profiles?
          profiles = _.map(profiles, (profile) ->
            return new Identity({keybase_profile: profile, isPriv: false})
          )
          @setState({results: profiles, loading: false})
        else
          @setState({results: [], loading: false})
        if @state.query != oldquery
          @debouncedSearch()
      )
    else
      # no query - empty out the results
      @setState({results: []})

  _importKey: (profile, event) =>
    # opens a popover requesting user to enter 1+ emails to associate with a
    # key - a button in the popover then calls _save to actually import the key
    popoverTarget = event.target.getBoundingClientRect()

    Actions.openPopover(
      <EmailPopover profile={profile} onPopoverDone={ @_popoverDone } />,
      {originRect: popoverTarget, direction: 'left'}
    )

  _popoverDone: (addresses, identity) =>
    if addresses.length < 1
      # no email addresses added, noop
      return
    else
      identity.addresses = addresses
      # TODO validate the addresses?
      @_save(identity)

  _save: (identity) =>
    # save/import a key from keybase
    keybaseUsername = identity.keybase_profile.components.username.val

    kb.getKey(keybaseUsername, (error, key) =>
      if error
        console.error error
      else
        PGPKeyStore.saveNewKey(identity, key)
    )

  _queryChange: (event) =>
    emailQuery = RegExpUtils.emailRegex().test(event.target.value)
    @setState({query: event.target.value, searchedByEmail: emailQuery})
    @debouncedSearch()

  render: ->
    profiles = _.map(@state.results, (profile) =>

      # allow for overriding the import function
      if typeof @props.importFunc is "function"
        boundFunc = @props.importFunc
      else
        boundFunc = @_importKey

      saveButton = (<button title="Import" className="btn btn-toolbar" onClick={ (event) => boundFunc(profile, event) } ref="button">
        Import Key
      </button>
      )

      # TODO improved deduping? tricky because of the kbprofile - email association
      if not profile.keyPath?
        return <KeybaseUser profile={profile} actionButton={ saveButton } />
    )

    if not profiles? or profiles.length < 1
      profiles = []

    badSearch = null
    loading = null
    empty = null

    if profiles.length < 1 and @state.searchedByEmail
      badSearch = <span className="bad-search-msg">Keybase cannot be searched by email address. <br/>Try entering a name, or a username from GitHub, Keybase or Twitter.</span>

    if @state.loading
      loading = <RetinaImg style={width: 20, height: 20, marginTop: 2} name="inline-loading-spinner.gif" mode={RetinaImg.Mode.ContentPreserve} />

    <div className="keybase-search">
      <div className="searchbar">
        <input type="text" value={ @state.query } placeholder="Search for PGP public keys on Keybase" ref="searchbar" onChange={@_queryChange} />
        {empty}
        <div className="loading">{ loading }</div>
      </div>
      <div className="results" ref="results">
        { profiles }
        { badSearch }
      </div>
    </div>
