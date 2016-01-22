React = require 'react'
_ = require 'underscore'
{Flexbox, RetinaImg} = require 'nylas-component-kit'
PluginsActions = require './plugins-actions'

class Package extends React.Component
  @displayName: 'Package'

  @propTypes:
    'package': React.PropTypes.object.isRequired

  constructor: (@props) ->

  render: =>
    actions = []
    extras = []

    if @props.package.icon
      icon = <img src="nylas://#{@props.package.name}/#{@props.package.icon}" style={width:50} />
    else
      icon = <RetinaImg name="plugin-icon-default.png"/>


    if @props.package.installed
      if @props.package.category in ['user' ,'dev', 'example']
        if @props.package.enabled
          actions.push <div className="btn btn-small" onClick={@_onDisablePackage}>Disable</div>
        else
          actions.push <div className="btn btn-small" onClick={@_onEnablePackage}>Enable</div>
      if @props.package.category is 'user'
        actions.push <div className="btn btn-small" onClick={@_onUninstallPackage}>Uninstall</div>
      if @props.package.category is 'dev'
        actions.push <div className="btn btn-small" onClick={@_onShowPackage}>Show...</div>

    else if @props.package.installing
      actions.push <div className="btn btn-small">Installing...</div>
    else
      actions.push <div className="btn btn-small" onClick={@_onInstallPackage}>Install</div>

    {name, description, title} = @props.package

    if @props.package.newerVersionAvailable
      extras.push(
        <div className="padded update-info">
          A newer version is available: {@props.package.newerVersion}
          <div className="btn btn-small btn-emphasis" onClick={@_onUpdatePackage}>Update</div>
        </div>
      )

    <Flexbox className="package" direction="row">
      <div className="icon" style={flexShink: 0}>{icon}</div>
      <div className="info">
        <div className="title">{title ? name}</div>
        <div className="description">{description}</div>
      </div>
      <div className="actions">{actions}</div>
      {extras}
    </Flexbox>

  _onDisablePackage: =>
    PluginsActions.disablePackage(@props.package)

  _onEnablePackage: =>
    PluginsActions.enablePackage(@props.package)

  _onUninstallPackage: =>
    PluginsActions.uninstallPackage(@props.package)

  _onUpdatePackage: =>
    PluginsActions.updatePackage(@props.package)

  _onInstallPackage: =>
    PluginsActions.installPackage(@props.package)

  _onShowPackage: =>
    PluginsActions.showPackage(@props.package)

module.exports = Package
