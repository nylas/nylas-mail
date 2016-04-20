{Utils, React} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
KeybaseUser = require '../lib/keybase-user'
kb = require './keybase'
_ = require 'underscore'

module.exports =
class KeybaseSearch extends React.Component
  @displayName: 'KeybaseSearch'

  constructor: (props) ->
    super(props)
    @state = {
      query: ""
      results: []
      loading: false
    }

    @debouncedSearch =  _.debounce(@_search, 200)

  _search: ->
    if @state.query != "" and @state.loading == false
      @setState({loading: true})
      kb.autocomplete(@state.query, (error, profiles) =>
        if profiles?
          profiles = _.map(profiles, (profile) ->
            return {keybase_user: profile}
          )
          @setState({results: profiles, loading: false})
        else
          @setState({results: [], loading: false})
      )
    else
      # no query - empty out the results
      @setState({results: []})

  _queryChange: (event) =>
    @setState({query: event.target.value})
    @debouncedSearch()

  render: ->
    profiles = _.map(@state.results, (profile) =>
      # TODO filter out or (better) merge in people that we already have keys for
      if profile.key?.key?
        uid = profile.key.key.get_pgp_fingerprint().toString('hex')
      else if profile.keybase_user?
        uid = profile.keybase_user.uid
      return <KeybaseUser profile={profile} key={profile.keybase_user.uid} />
    )

    if not profiles? or profiles.length < 1
      profiles = []

    if @state.loading
      loading = "LOADING"
    else
      loading = null

    <div className="keybase-search">
      <div className="searchbar">
        <input type="text" placeholder="...or, search Keybase" ref="searchbar" onChange={@_queryChange} />
      </div>

      { loading }
      <div className="results" ref="results">
        { profiles }
      </div>
    </div>
