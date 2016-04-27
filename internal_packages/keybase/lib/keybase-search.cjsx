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

  @defaultProps:
    initialSearch: ""

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

  _popoverDone: (addresses, profile) =>
    # closes the popover, saves a key if an email was entered
    keybaseUsername = profile.keybase_profile.components.username.val

    if addresses.length < 1
      # no email addresses added, nop
      return
    else
      @_save(keybaseUsername, addresses[0])

    if addresses.length > 1
      # add any extra ddresses the user entered
      _.each(addresses.slice(1), (address) =>
        @_addEmail(address)
      )

  _save: (keybaseUsername, address) =>
    # save/import a key from keybase
    kb.getKey(keybaseUsername, (error, key) =>
      if error
        console.error "Unable to fetch key for #{keybaseUsername}"
      else
        PGPKeyStore.saveNewKey(address, key, true) # isPub = true
    )

  _queryChange: (event) =>
    @setState({query: event.target.value})
    @debouncedSearch()

  render: ->
    profiles = _.map(@state.results, (profile) =>
      # TODO filter out or (better) merge in people that we already have keys for
      saveButton = (<button title="Import" className="btn btn-toolbar" onClick={ => @_importKey(profile) } ref="button">
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
