React = require 'react'
Page = require './page'
{RetinaImg, ConfigPropContainer} = require 'nylas-component-kit'
{EdgehillAPI} = require 'nylas-exports'
OnboardingActions = require './onboarding-actions'

InitialPackages = [{
  'name': 'Templates',
  'description': 'Templates let you fill an email with a pre-set body of text and a snumber of fields you can fill quickly to save time.'
  'icon': 'setup-icon-templates.png'
}, {
  'name': 'Signatures',
  'description': 'Select from and edit mutiple signatures that N1 will automatically append to your sent messages.'
  'icon': 'setup-icon-signatures.png'
},{
  'name': 'Github',
  'description': 'Adds Github quick actions to many emails, and allows you to see the Github profiles of the people you email.'
  'icon': 'setup-icon-github.png'
}]

class SlideSwitch extends React.Component
  @propTypes:
    active: React.PropTypes.bool.isRequired

  constructor: (@props) ->

  render: =>
    classnames = "slide-switch"
    if @props.active
      classnames += " active"

    <div className={classnames} onClick={@props.onChange}>
      <div className="handle"></div>
    </div>


class InitialPackagesList extends React.Component
  @displayName: "InitialPackagesList"

  render: =>
    <div>
      {InitialPackages.map (item) =>
        <div className="initial-package" key={item.name}>
          <RetinaImg name={item.icon} mode={RetinaImg.Mode.ContentPreserve} />
          <div className="name">{item.name}</div>
          <div className="description">{item.description}</div>
          <SlideSwitch active={@_isPackageEnabled(item.packageName)} onChange={ => @_togglePackageEnabled(item.packageName)}/>
        </div>
      }
    </div>

  _isPackageEnabled: (packageName) =>
    !atom.packages.isPackageDisabled(packageName)

  _togglePackageEnabled: (packageName) =>
    if atom.packages.isPackageDisabled(packageName)
      atom.packages.enablePackage(packageName)
    else
      atom.packages.disablePackage(packageName)

class InitialPackagesPage extends Page
  @displayName: "InitialPackagesPage"

  render: =>
    <div className="page no-top opaque" style={width:900, height:650}>
      <div className="back" onClick={@_onPrevPage}>
        <RetinaImg name="onboarding-back.png" mode={RetinaImg.Mode.ContentPreserve}/>
      </div>
      <h1 style={paddingTop: 20}>Welcome to N1</h1>
      <h4 style={marginBottom: 50}>Explore packages</h4>
      <p>
      Packages lie at the heart of N1—you can enable community packages or build<br/>
      your own to create the perfect workflow. Want to enable a few packages now?
      </p>

      <ConfigPropContainer>
        <InitialPackagesList />
      </ConfigPropContainer>
      <button className="btn btn-large" onClick={@_onGetStarted}>Start Using N1</button>
    </div>

  _onPrevPage: =>
    OnboardingActions.moveToPage('initial-preferences')

  _onGetStarted: =>
    ipc = require 'ipc'
    ipc.send('login-successful')

module.exports = InitialPackagesPage
