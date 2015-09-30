React = require 'react'
shell = require 'shell'
classnames = require 'classnames'
{RetinaImg, TimeoutTransitionGroup} = require 'nylas-component-kit'
OnboardingActions = require './onboarding-actions'

class WelcomePage extends React.Component
  @displayName: "WelcomePage"

  constructor: (@props) ->
    @state =
      step: 0
      lastStep: 0

  render: ->
    <div className="welcome-page page opaque">
      <div className="quit" onClick={ -> OnboardingActions.closeWindow() }>
        <RetinaImg name="onboarding-close.png" mode={RetinaImg.Mode.ContentPreserve}/>
      </div>
      <div className="steps-container">{@_renderSteps()}</div>
      <div className="footer">{@_renderButtons()}</div>
    </div>

  _renderButtons: ->
    buttons = []
    # if @state.step > 0
    #   buttons.push <span key="back" className="btn-back" onClick={@_onBack}>Back</span>
    btnText = if @state.step is 2 then "Get Started" else "Continue"
    buttons.push <button key="next" className="btn btn-large btn-continue" onClick={@_onContinue}>{btnText}</button>
    return buttons

  _renderSteps: -> [
    @_renderStep0()
    @_renderStep1()
    @_renderStep2()
  ]

  _stepClass: (n) ->
    obj =
      "step-wrap": true
      "active": @state.step is n
    obj["step-#{n}-wrap"] = true
    className = classnames(obj)
    return className

  _renderStep0: ->
    <div className={@_stepClass(0)} key="step-0">
      <RetinaImg className="logo" style={zoom: 0.20, marginTop: 60} url="nylas://onboarding/assets/nylas-pictograph@2x.png" mode={RetinaImg.Mode.ContentIsMask} />
      <p className="hero-text" style={marginTop: 30, fontSize: 44}>Say hello to N1.</p>
      <p className="sub-text" style={marginTop: 0, fontSize: 24}>The next-generation email platform.</p>
      <div style={fontSize:17, marginTop: 45}>Built with ❤︎ by Nylas</div>
      <RetinaImg className="icons" style={position: "absolute", left: -45, top: 130} url="nylas://onboarding/assets/shapes-left@2x.png" mode={RetinaImg.Mode.ContentIsMask} />
      <RetinaImg className="icons" style={position: "absolute", right: -40, top: 130} url="nylas://onboarding/assets/shapes-right@2x.png" mode={RetinaImg.Mode.ContentIsMask} />
      {@_renderNavBubble(0)}
    </div>

  _renderStep1: ->
    <div className={@_stepClass(1)} key="step-1">
      <p className="hero-text" style={marginTop: 40}>Developers welcome.</p>
      <div className="gear-outer-container"><div className="gear-container">
        {@_gears()}
      </div></div>
      <RetinaImg className="gear-small" mode={RetinaImg.Mode.ContentPreserve}
                 url="nylas://onboarding/assets/gear-small@2x.png" />
      <RetinaImg className="wrench" mode={RetinaImg.Mode.ContentPreserve}
                 url="nylas://onboarding/assets/wrench@2x.png" />

      <p className="sub-text">N1 is built with modern web technologies and easy to extend with JavaScript.</p>
      {@_renderNavBubble(1)}
    </div>

  _gears: ->
    gears = []
    for i in [0..3]
      gears.push <RetinaImg className="gear-large gear-large-#{i}"
                             mode={RetinaImg.Mode.ContentPreserve}
                             url="nylas://onboarding/assets/gear-large@2x.png" />
    return gears

  _renderStep2: ->
    <div className={@_stepClass(2)} key="step-2">
      <p className="hero-text" style={marginTop: 40}>N1 is made possible by the Nylas Sync Engine</p>
      <div className="cell-wrap">
        <div className="cell" style={float: "left"}>
          <RetinaImg mode={RetinaImg.Mode.ContentPreserve}
                     style={paddingTop: 4, paddingBottom: 4}
                     url="nylas://onboarding/assets/cloud@2x.png" />
          <p>A modern API layer for<br/>email, contacts &amp; calendar</p>
          <a onClick={=> @_open("https://github.com/nylas/sync-engine")}>more info</a>
        </div>
        <div className="cell" style={float: "right"}>
          <RetinaImg mode={RetinaImg.Mode.ContentPreserve}
                     url="nylas://onboarding/assets/lock@2x.png" />
          <p>Secured using<br/>bank-grade encryption</p>
          <a onClick={=> @_open("https://nylas.com/security/")}>more info</a>
        </div>
      </div>
      {@_renderNavBubble(2)}
    </div>

  _open: (link) ->
    shell.openExternal(link)
    return

  _renderNavBubble: (step=0) ->
    bubbles = [0..2].map (n) =>
      active = if n is step then "active" else ""
      <div className="nav-bubble #{active}"
           onClick={ => @setState step: n }></div>

    <div className="nav-bubbles">
      {bubbles}
    </div>

  _onBack: =>
    @setState(step: @state.step - 1)

  _onContinue: =>
    if @state.step < 2
      @setState(step: @state.step + 1)
    else
      OnboardingActions.moveToPage("account-choose")

module.exports = WelcomePage
