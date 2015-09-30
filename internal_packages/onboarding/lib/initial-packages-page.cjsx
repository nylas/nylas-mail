React = require 'react'
path = require 'path'
{RetinaImg, ConfigPropContainer} = require 'nylas-component-kit'
{EdgehillAPI} = require 'nylas-exports'
OnboardingActions = require './onboarding-actions'
InitialPackagesStore = require './initial-packages-store'

RunningPackageInstalls = 0

class InstallButton extends React.Component
  constructor: (@props) ->
    @state =
      installed: atom.packages.resolvePackagePath(@props.package.name)?
      installing: false

  render: =>
    classname = "btn btn-install"
    classname += " installing" if @state.installing
    classname += " installed" if @state.installed

    <div className={classname} onClick={@_onInstall}></div>

  _onInstall: =>
    return false unless @props.package.path
    RunningPackageInstalls += 1
    @setState(installing: true)
    atom.packages.installPackageFromPath @props.package.path, (err) =>
      RunningPackageInstalls -= 1
      @props.onPackageInstaled()
      @setState({
        installing: false
        installed: atom.packages.resolvePackagePath(@props.package.name)?
      })

class InitialPackagesPage extends React.Component
  @displayName: "InitialPackagesPage"

  constructor: (@props) ->
    @state = @getStateFromStores()

  componentDidMount: =>
    @unlisten = InitialPackagesStore.listen =>
      @setState(@getStateFromStores())

  componentWillUnmount: =>
    @unlisten?()

  getStateFromStores: =>
    packages: InitialPackagesStore.starterPackages
    error: InitialPackagesStore.lastError

  render: =>
    <div className="page opaque" style={width:900, height:650}>
      <div className="back" onClick={@_onPrevPage}>
        <RetinaImg name="onboarding-back.png" mode={RetinaImg.Mode.ContentPreserve}/>
      </div>

      <h1 style={paddingTop: 60, marginBottom: 20}>Explore packages</h1>
      <p style={paddingBottom: 20}>
        Packages lie at the heart of N1 and give it it's powerful features.<br/>
        Want to enable a few example packages now? They'll be installed to <code>~/.nylas</code>
      </p>

      <div>
        {@_renderError()}
        {@state.packages.map (item) =>
          <div className="initial-package" key={item.name}>
            <img src={item.iconPath} style={width:50} />
            <div className="install-container">
              <InstallButton package={item} onPackageInstaled={@_onPackageInstaled} />
            </div>
            <div className="name">{item.title}</div>
            <div className="description">{item.description}</div>
          </div>
        }
      </div>
      <button className="btn btn-large btn-get-started btn-emphasis"
              style={marginTop: 15}
              onClick={@_onGetStarted}>
        {@_renderStartSpinner()}
        Start Using N1
      </button>
    </div>

  _renderError: =>
    return false unless @state.error
    <div className="error">{@state.error.toString()}</div>

  _renderStartSpinner: =>
    return false unless @state.waitingToGetStarted
    <div className="spinner"></div>

  _onPrevPage: =>
    OnboardingActions.moveToPage('initial-preferences')

  _onPackageInstaled: =>
    if RunningPackageInstalls is 0 and @state.waitingToGetStarted
      @_onGetStarted()

  _onGetStarted: =>
    if RunningPackageInstalls > 0
      @setState(waitingToGetStarted: true)
    else
      require('ipc').send('account-setup-successful')

module.exports = InitialPackagesPage
