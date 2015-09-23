React = require 'react'
Page = require './page'
{RetinaImg, TimeoutTransitionGroup} = require 'nylas-component-kit'
OnboardingActions = require './onboarding-actions'

class WelcomePage extends Page
  @displayName: "WelcomePage"

  constructor: (@props) ->
    @state =
      step: 0

  render: =>
    buttons = []
    if @state.step > 0
      buttons.push <button key="back" className="btn btn-large" style={marginRight: 10}  onClick={@_onBack}>Back</button>
    buttons.push <button key="next" className="btn btn-large" onClick={@_onContinue}>Continue</button>

    <div className="page no-top opaque" style={width: 667, display: "inline-block"}>
      {@_renderClose("close")}
      <TimeoutTransitionGroup leaveTimeout={300}
                              enterTimeout={300}
                              className="welcome-image-container"
                              transitionName="welcome-image">
        {@_renderStep()}
      </TimeoutTransitionGroup>

      <div style={textAlign:'center', paddingTop:30, paddingBottom:30}>
        {buttons}
      </div>
    </div>

  _renderStep: =>
    if @state.step is 0
      <div className="welcome-image" key="step-0">
        <RetinaImg name="welcome1bg.png" mode={RetinaImg.Mode.ContentPreserve} />
        <RetinaImg name="welcome1icon.png" mode={RetinaImg.Mode.ContentPreserve} style={position:'absolute', top:'50%', left:'50%', transform:'translate(-50%, -50%)'}/>
      </div>
    else if @state.step is 1
      <div className="welcome-image" key="step-1">
        <RetinaImg name="welcome2bg.png" mode={RetinaImg.Mode.ContentPreserve} />
      </div>
    else if @state.step is 2
      <div className="welcome-image" key="step-2">
        <RetinaImg name="welcome3bg.png" mode={RetinaImg.Mode.ContentPreserve} />
      </div>

  _onBack: =>
    @setState(step: @state.step - 1)

  _onContinue: =>
    if @state.step < 2
      @setState(step: @state.step + 1)
    else
      OnboardingActions.moveToPage("account-choose")

module.exports = WelcomePage
