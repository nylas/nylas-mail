{Utils, React, ReactDOM, Actions} = require 'nylas-exports'
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
    importFunc: React.PropTypes.function
    # TODO consider just passing in a pre-specified email instead of a func?

  @defaultProps:
    initialSearch: ""
    importFunc: false

  constructor: (props) ->
    super(props)
    @state = {
      query: props.initialSearch
      results: []
      loading: false
    }

    @debouncedSearch =  _.debounce(@_search, 200)

  componentDidMount: ->
    @_search()

  _search: ->
    if @state.query != "" and @state.loading == false
      @setState({loading: true})
      kb.autocomplete(@state.query, (error, profiles) =>
        if profiles?
          profiles = _.map(profiles, (profile) ->
            return new Identity({keybase_profile: profile})
          )
          @setState({results: profiles, loading: false})
        else
          @setState({results: [], loading: false})
      )
    else
      # no query - empty out the results
      @setState({results: []})

  _importKey: (profile) =>
    # opens a popover requesting user to enter 1+ emails to associate with a
    # key - a button in the popover then calls _save to actually import the key
    popoverTarget = ReactDOM.findDOMNode(@refs.button).getBoundingClientRect()

    Actions.openPopover(
      <EmailPopover profile={profile} onPopoverDone={ @_popoverDone } />,
      {originRect: popoverTarget, direction: 'left'}
    )

  _popoverDone: (addresses, identity) =>
    # closes the popover, saves a key if an email was entered
    keybaseUsername = identity.keybase_profile.components.username.val

    if addresses.length < 1
      # no email addresses added, nop
      return
    else
      @_save(identity, addresses[0])

    if addresses.length > 1
      # add any extra ddresses the user entered
      _.each(addresses.slice(1), (address) =>
        @_addEmail(address)
      )

  _save: (identity, address) =>
    # save/import a key from keybase
    kb.getKey(keybaseUsername, (error, key) =>
      if error
        console.error error
      else
        PGPKeyStore.saveNewKey(identity, key, true) # isPub = true
    )

  _queryChange: (event) =>
    @setState({query: event.target.value})
    @debouncedSearch()

  render: ->
    profiles = _.map(@state.results, (profile) =>
      # TODO filter out or (better) merge in people that we already have keys for

      # allow for overriding the import function
      if @props.importFunc?
        boundFunc = @props.importFunc
      else
        boundFunc = @_importKey

      saveButton = (<button title="Import" className="btn btn-toolbar" onClick={ => boundFunc(profile) } ref="button">
        Import Key
      </button>
      )

      return <KeybaseUser profile={profile} key={profile.clientId} actionButton={ saveButton } />
    )

    if not profiles? or profiles.length < 1
      profiles = []

    if @state.loading
      loading = "LOADING"
    else
      loading = null

    <div className="keybase-search">
      <div className="searchbar">
        <input type="text" value={ @state.query } placeholder="...or, search Keybase" ref="searchbar" onChange={@_queryChange} />
      </div>

      { loading }
      <div className="results" ref="results">
        { profiles }
      </div>
    </div>
