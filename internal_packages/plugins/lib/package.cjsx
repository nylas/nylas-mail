React = require 'react'
_ = require 'underscore'

PluginsActions = require './plugins-actions'

class Package extends React.Component
  @displayName: 'Package'

  @propTypes:
    'package': React.PropTypes.object.isRequired

  constructor: (@props) ->

  render: =>
    actions = []
    extras = []

    if @props.package.installed
      if @props.package.category in ['user' ,'dev']
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

    {name, description} = @props.package

    if @props.package.newerVersionAvailable
      extras.push(
        <div className="padded update-info">
          A newer version is available: {@props.package.newerVersion}
          <div className="btn btn-small btn-emphasis" onClick={@_onUpdatePackage}>Update</div>
        </div>
      )

    <div className="package">
      <div className="padded">
        <div className="actions">{actions}</div>
        <div className="title">{name}</div>
        <div className="description">{description}</div>
      </div>
      {extras}
    </div>

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
