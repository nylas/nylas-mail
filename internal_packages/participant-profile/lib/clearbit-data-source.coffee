# This file is in coffeescript just to use the existential operator!
{AccountStore, EdgehillAPI} = require 'nylas-exports'

module.exports = class ClearbitDataSource
  clearbitAPI: ->
    return "https://person.clearbit.com/v2/combined"

  find: ({email}) ->
    tok = AccountStore.tokenForAccountId(AccountStore.accounts()[0].id)
    new Promise (resolve, reject) =>
      EdgehillAPI.request
        auth:
          user: tok
          pass: ""
        path: "/proxy/clearbit/#{@clearbitAPI()}/find?email=#{email}",
        success: (body, response) =>
          resolve(@parseResponse(body, response, email))
        error: reject

  # The clearbit -> Nylas adapater
  parseResponse: (body={}, response, requestedEmail) ->
    # This means it's in the process of fetching. Return null so we don't
    # cache and try again.
    if response.statusCode isnt 200
      return null

    person = body.person

    # This means there was no data about the person available. Return a
    # valid, but empty object for us to cache. This can happen when we
    # have company data, but no personal data.
    if not person
      return {email: requestedEmail}

    return {
      cacheDate: Date.now()
      email: person.email # Used as checksum
      bio: person.bio ? person.twitter?.bio ? person.aboutme?.bio,
      location: person.location ? person.geo?.city
      currentTitle: person.employment?.title,
      currentEmployer: person.employment?.name,
      profilePhotoUrl: person.avatar,
      socialProfiles: @_socialProfiles(person)
    }

  _socialProfiles: (person={}) ->
    profiles = {}
    if (person.twitter?.handle ? "").length > 0
      profiles.twitter =
        handle: person.twitter.handle
        url: "https://twitter.com/#{person.twitter.handle}"
    if (person.facebook?.handle ? "").length > 0
      profiles.facebook =
        handle: person.facebook.handle
        url: "https://facebook.com/#{person.facebook.handle}"
    if (person.linkedin?.handle ? "").length > 0
      profiles.linkedin =
        handle: person.linkedin.handle
        url: "https://linkedin.com/#{person.linkedin.handle}"

    return profiles
