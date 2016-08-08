# This file is in coffeescript just to use the existential operator!
{AccountStore, EdgehillAPI} = require 'nylas-exports'

MAX_RETRY = 10

module.exports = class ClearbitDataSource
  clearbitAPI: ->
    return "https://person.clearbit.com/v2/combined"

  find: ({email, tryCount}) ->
    if (tryCount ? 0) >= MAX_RETRY
      return Promise.resolve(null)
    new Promise (resolve, reject) =>
      EdgehillAPI.makeRequest
        authWithNylasAPI: true
        path: "/proxy/clearbit/#{@clearbitAPI()}/find?email=#{email}",
        success: (body, response) =>
          @parseResponse(body, response, email, tryCount).then(resolve).catch(reject)
        error: reject

  # The clearbit -> Nylas adapater
  parseResponse: (body={}, response, requestedEmail, tryCount=0) =>
    new Promise (resolve, reject) =>
      # This means it's in the process of fetching. Return null so we don't
      # cache and try again.
      if response.statusCode is 202
        setTimeout =>
          @find({email: requestedEmail, tryCount: tryCount+1}).then(resolve).catch(reject)
        , 1000
        return
      else if response.statusCode isnt 200
        resolve(null)
        return

      person = body.person

      # This means there was no data about the person available. Return a
      # valid, but empty object for us to cache. This can happen when we
      # have company data, but no personal data.
      if not person
        person = {email: requestedEmail}

      resolve({
        cacheDate: Date.now()
        email: requestedEmail # Used as checksum
        bio: person.bio ? person.twitter?.bio ? person.aboutme?.bio,
        location: person.location ? person.geo?.city
        currentTitle: person.employment?.title,
        currentEmployer: person.employment?.name,
        profilePhotoUrl: person.avatar,
        rawClearbitData: body,
        socialProfiles: @_socialProfiles(person)
      })

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
