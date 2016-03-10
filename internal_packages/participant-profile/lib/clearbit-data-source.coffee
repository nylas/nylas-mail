# This file is in coffeescript just to use the existential operator!
{AccountStore, EdgehillAPI} = require 'nylas-exports'

module.exports = class ClearbitDataSource
  clearbitAPI: ->
    return "https://person.clearbit.com/v2/combined"

  find: ({email}) ->
    n1_id = NylasEnv.config.get('updateIdentity')
    new Promise (resolve, reject) =>
      EdgehillAPI.request
        path: "/proxy/clearbit/#{@clearbitAPI()}/find?email=#{email}&n1_id=#{n1_id}",
        success: (body) =>
          resolve(@parseResponse(body))
        error: reject

  # The clearbit -> Nylas adapater
  parseResponse: (resp={}) ->
    person = resp.person
    return null unless person
    cacheDate: Date.now()
    email: person.email # Used as checksum
    bio: person.bio ? person.twitter?.bio ? person.aboutme?.bio,
    location: person.location ? person.geo?.city
    currentTitle: person.employment?.title,
    currentEmployer: person.employment?.name,
    profilePhotoUrl: person.avatar,
    socialProfiles: @_socialProfiles(person)

  _socialProfiles: (person={}) ->
    profiles = {}
    if person.twitter
      profiles.twitter =
        handle: person.twitter.handle
        url: "https://twitter.com/#{person.twitter.handle}"
    if person.facebook
      profiles.facebook =
        handle: person.facebook.handle
        url: "https://facebook.com/#{person.facebook.handle}"
    if person.linkedin
      profiles.linkedin =
        handle: person.linkedin.handle
        url: "https://linkedin.com/#{person.linkedin.handle}"

    return profiles
