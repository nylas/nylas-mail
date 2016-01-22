
RefreshingJSONCache = require './refreshing-json-cache'
{NylasAPI} = require 'nylas-exports'

# Stores contact rankings
class ContactRankingsCache extends RefreshingJSONCache
  constructor: (accountId) ->
    @_accountId = accountId
    super({
      key: "ContactRankingsFor#{accountId}",
      version: 1,
      refreshInterval: 60 * 60 * 1000 * 24 # one day
    })

  fetchData: (callback) =>
    return if NylasEnv.inSpecMode()

    NylasAPI.makeRequest
      accountId: @_accountId
      path: "/contacts/rankings"
      returnsModel: false
    .then (json) =>
      return unless json and json instanceof Array

      # Convert rankings into the format needed for quick lookup
      rankings = {}
      for [email, rank] in json
        rankings[email.toLowerCase()] = rank
      callback(rankings)

    .catch (err) =>
      console.warn("Request for Contact Rankings failed for
                    account #{@_accountId}. #{err}")

module.exports = ContactRankingsCache
