_ = require 'underscore-plus'
React = require "react"

{Actions} = require 'inbox-exports'

module.exports =
SidebarFullContactDetails = React.createClass

  propTypes:
    contact: React.PropTypes.object
    fullContact: React.PropTypes.object

  render: ->
    <div className="full-contact">
      <div className="header">
        {@_profilePhoto()}
        <h1 className="name">{@_name()}</h1>
      </div>
      <div className="subheader"
           style={display: if @_showSubheader() then "block" else "none"}>
        <div className="title">{@_title()}</div>
        <div className="company">{@_company()}</div>
      </div>
      {@_renderActions()}
    </div>

  _renderActions: ->
    <div className="actions">
    </div>

  _showSubheader: ->
    @_title().length > 0 or @_company().length > 0

  _name: ->
    (@props.fullContact.contactInfo?.fullName) ? @props.contact?.name

  _title: ->
    org = @_primaryOrg()
    return "" unless org?
    if org.current and org.title?
      return org.title
    else if not org.current and org.title?
      return "Former #{org.title}"
    else return ""

  _company: ->
    location = @props.fullContact.demographics?.locationGeneral ? ""
    name = @_primaryOrg()?.name ? ""
    if name.length > 0 and location.length > 0
      return "#{name} (#{location})"
    else if name.length > 0
      return name
    else if location.length > 0
      return "(#{location})"
    else return ""

  _primaryOrg: ->
    orgs = @props.fullContact.organizations ? []
    org = _.findWhere orgs, isPrimary: true
    if not org? then org = orgs[0]
    return org

  _profilePhoto: ->
    photos = @props.fullContact.photos ? []
    photo = _.findWhere photo, isPrimary: true
    if not photo? then photo = _.findWhere photo, typeId: "linkedin"
    if not photo? then photo = photos[0]
    if photo? and photo.url?
      return <img src={photo.url} className="profile-photo" />
    else return ""
