React = require 'react'
path = require 'path'
{RetinaImg, ConfigPropContainer} = require 'nylas-component-kit'
{EdgehillAPI} = require 'nylas-exports'
OnboardingActions = require './onboarding-actions'

InitialPackages = [{
  'label': 'Templates',
  'packageName': 'templates',
  'description': 'Templates let you fill an email with a pre-set body of text and a snumber of fields you can fill quickly to save time.'
  'icon': 'setup-icon-templates.png'
}, {
  'label': 'Signatures',
  'packageName': 'signatures',
  'description': 'Select from and edit mutiple signatures that N1 will automatically append to your sent messages.'
  'icon': 'setup-icon-signatures.png'
},{
  'label': 'Github',
  'packageName': 'N1-Github-Contact-Card-Section'
  'description': 'Adds Github quick actions to many emails, and allows you to see the Github profiles of the people you email.'
  'icon': 'setup-icon-github.png'
}]

class InstallButton extends React.Component
  constructor: (@props) ->
    @state =
      installed: atom.packages.resolvePackagePath(@props.packageName)?
      installing: false

  render: =>
    classname = "btn btn-install"
    classname += " installing" if @state.installing
    classname += " installed" if @state.installed

    <div className={classname} onClick={@_onInstall}></div>

  _onInstall: =>
    return false unless @props.packageName
    {resourcePath} = atom.getLoadSettings()
    packagePath = path.join(resourcePath, "examples", @props.packageName)
    @setState(installing: true)
    atom.packages.installPackageFromPath packagePath, (err) =>
      @setState({
        installing: false
        installed: atom.packages.resolvePackagePath(@props.packageName)?
      })

  componentWillUnmount: =>
    @listener?.dispose()

class InitialPackagesPage extends React.Component
  @displayName: "InitialPackagesPage"

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
        {InitialPackages.map (item) =>
          <div className="initial-package" key={item.label}>
            <RetinaImg name={item.icon} mode={RetinaImg.Mode.ContentPreserve} />
            <div className="install-container">
              <InstallButton packageName={item.packageName} />
            </div>
            <div className="name">{item.label}</div>
            <div className="description">{item.description}</div>
          </div>
        }
      </div>
      <button className="btn btn-large btn-emphasis" style={marginTop: 15} onClick={@_onGetStarted}>Start Using N1</button>
    </div>

  _onPrevPage: =>
    OnboardingActions.moveToPage('initial-preferences')

  _onGetStarted: =>
    ipc = require 'ipc'
    ipc.send('account-setup-successful')

module.exports = InitialPackagesPage
