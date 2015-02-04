_ = require 'underscore-plus'
React = require "react"
SidebarFullContactChip = require "./sidebar-fullcontact-chip.cjsx"

{Actions} = require 'inbox-exports'

module.exports =
SidebarFullContactDetails = React.createClass

  render: ->
    keys = Object.keys @props.data
    status = @props.data?.status
    if keys.length > 0 and status is 200
      <div className="fullcontact">
        {@_makeHeader()}
        {@_makeProfiles()}
      </div>
    else
      <SidebarFullContactChip contacts={@props.contacts}
                              compact={true}
                              selectContact={@props.selectContact}/>

   _makeHeader: ->
    <div className="fullcontact-header">
      <SidebarFullContactChip contacts={@props.contacts}
                              compact=true
                              selectContact={@props.selectContact}/>
      <span className="fullcontact-avatar-container">
        <img src={@_getProfilePhoto()} className="fullcontact-avatar-image" />
      </span>
      <h3>{@props.data.contactInfo?.fullName}</h3>
      {@_getBio()}
      <h6>{@props.data.demographics?.locationGeneral}</h6>
      <h6>{@props.email}</h6>
    </div>

  _makeProfiles: ->
    <div className="fullcontact-profiles">
      {@_getSocialProfiles()}
    </div>

  _getProfilePhoto: ->
    photos = @props.data.photos
    url = ''
    for photo in photos
      if photo.typeId == 'linkedin'
        return photo.url
      else if photo.typeId == 'gravatar'
        return photo.url
      else if photo.typeId == 'facbook'
        return photo.url
      else
        url = photo.url
    return url

  _getBio: ->
    @socialData = {}
    for profile in @props.data.socialProfiles
      @socialData[profile.typeId] = profile
    if @socialData.linkedin?
      return <h5>{@socialData.linkedin.bio}</h5>
    return <div></div>

  _getSocialProfiles: ->
    rankedProfiles = ['linkedin', 'aboutme', 'twitter', 'googleplus',
                      'facebook', 'angellist', 'flickr', 'foursquare',
                      'github', 'bitbucket', 'goodreads', 'dribbble',
                      'hackernews', 'klout', 'lastfm', 'pinterest',
                      'quora', 'skype', 'soundcloud', 'stackoverflow',
                      'tripit', 'youtube', 'wordpress']
    body = []
    for profile in rankedProfiles
      if @socialData[profile]?
        if @socialData[profile].url?
          body.push <div><a href={@socialData[profile].url}>{@socialData[profile].typeName}</a></div>
    for k,v of @socialData
      if k not in rankedProfiles
        if v.url?
          body.push <div><a href={v.url}>{v.typeName}</a></div>
    return body
