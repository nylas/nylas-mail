React = require 'react'
path = require 'path'
{RetinaImg, ConfigPropContainer} = require 'nylas-component-kit'
{EdgehillAPI} = require 'nylas-exports'
OnboardingActions = require './onboarding-actions'

class InstallButton extends React.Component
  constructor: (@props) ->
    @state =
      installed: !NylasEnv.packages.isPackageDisabled(@props.package.name)

  render: =>
    classname = "btn btn-install"
    classname += " installed" if @state.installed

    <div className={classname} onClick={@_onInstall}></div>

  _onInstall: =>
    NylasEnv.packages.enablePackage(@props.package.name)
    @setState(installed: true)

class InitialPackagesPage extends React.Component
  @displayName: "InitialPackagesPage"

  constructor: (@props) ->
    @state =
      packages: NylasEnv.packages.getAvailablePackageMetadata().filter ({isStarterPackage}) => isStarterPackage

  render: =>
    <div className="page opaque" style={width:900, height:650}>
      <div className="back" onClick={@_onPrevPage}>
        <RetinaImg name="onboarding-back.png" mode={RetinaImg.Mode.ContentPreserve}/>
      </div>

      <h1 style={paddingTop: 60, marginBottom: 20}>Explore plugins</h1>
      <p style={paddingBottom: 20}>
        Plugins lie at the heart of N1 and give it its powerful features.<br/>
        Want to enable a few example plugins now? They'll be installed to <code>~/.nylas</code>
      </p>

      <div>
        {@state.packages.map (item) =>
          <div className="initial-package" key={item.name}>
            <img src="nylas://#{item.name}/#{item.icon}" style={width:50} />
            <div className="install-container">
              <InstallButton package={item} />
            </div>
            <div className="name">{item.title}</div>
            <div className="description">{item.description}</div>
          </div>
        }
      </div>
      <button className="btn btn-large btn-get-started btn-emphasis"
              style={marginTop: 15}
              onClick={@_onGetStarted}>
        Start Using N1
      </button>
    </div>

  _onPrevPage: =>
    OnboardingActions.moveToPage('initial-preferences')

  _onGetStarted: =>
    require('electron').ipcRenderer.send('account-setup-successful')

module.exports = InitialPackagesPage
