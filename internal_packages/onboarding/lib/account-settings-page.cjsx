React = require 'react'

ipc = require 'ipc'
{RetinaImg} = require 'nylas-component-kit'
{EdgehillAPI, NylasAPI, APIError} = require 'nylas-exports'

OnboardingActions = require './onboarding-actions'
NylasApiEnvironmentStore = require './nylas-api-environment-store'
Providers = require './account-types'
remote = require('remote')
dialog = remote.require('dialog')

class AccountSettingsPage extends React.Component
  @displayName: "AccountSettingsPage"

  constructor: (@props) ->
    @state =
      provider: @props.pageData.provider
      settings: {}
      fields: {}
      pageNumber: 0
      errorFieldNames: []
      errorMessage: null
      show_advanced: false

    @props.pageData.provider.settings.forEach (field) =>
      if field.default?
        @state.settings[field.name] = field.default

    if @state.provider.name is 'gmail'
      poll_attempt_id = 0
      done = false
      # polling with capped exponential backoff
      delay = 1000
      tries = 0
      poll = (id,initial_delay) =>
        _retry = =>
          tries++
          @_pollForGmailAccount((account) ->
            if account?
              done = true
              OnboardingActions.accountJSONReceived(account)
            else if tries < 10 and id is poll_attempt_id
              setTimeout(_retry, delay)
              delay *= 1.5 # exponential backoff
          )
        setTimeout(_retry,initial_delay)

      ipc.on('browser-window-focus', ->
        if not done  # hack to deactivate this listener when done
          poll_attempt_id++
          poll(poll_attempt_id,0)
      )
      poll(poll_attempt_id,2000)

  componentDidMount: ->

  componentWillUnmount: ->

  render: ->
    <div className="page account-setup">

      <div className="logo-container">
        <RetinaImg name={@state.provider.header_icon} mode={RetinaImg.Mode.ContentPreserve} className="logo"/>
      </div>

      {@_renderTitle()}

      <div className="back" onClick={@_fireMoveToPrevPage}>
        <RetinaImg name="onboarding-back.png"
                   mode={RetinaImg.Mode.ContentPreserve}/>
      </div>
      {@_renderErrorMessage()}
      <form className="settings">
        {@_renderFields()}
        {@_renderSettings()}
        {@_renderButton()}
      </form>

    </div>

  _onSettingsChanged: (event) =>
    field = event.target.dataset.field
    format = event.target.dataset.format
    int_formatter = (a) ->
      i = parseInt(a)
      if isNaN(i) then "" else i
    formatter = if format is 'integer' then int_formatter else (a) -> a
    settings = @state.settings
    if event.target.type is 'checkbox'
      settings[field] = event.target.checked
    else
      settings[field] = formatter(event.target.value)
    @setState({settings})

  _onValueChanged: (event) =>
    field = event.target.dataset.field
    fields = @state.fields
    fields[field] = event.target.value
    @setState({fields})

  _onFieldKeyPress: (event) =>
    if event.key in ['Enter', 'Return']
      pages = @state.provider.pages || []
      if pages.length > @state.pageNumber+1
        @_onNextButton()
      else
        @_onSubmit()

  _renderTitle: =>
    if @state.provider.name is 'gmail'
      <h2>
        Sign in to {@state.provider.displayName} in your browser.
      </h2>
    else if @state.provider.pages?.length > 0
      <h2>
        {@state.provider.pages[@state.pageNumber]}
      </h2>
    else
      <h2>
        Sign in to {@state.provider.displayName}
      </h2>

  _renderErrorMessage: =>
    if @state.errorMessage
      <div className="errormsg">{@state.errorMessage ? ""}</div>

  _fieldOnCurrentPage: (field) =>
    !@state.provider.pages || field.page is @state.pageNumber

  _renderFields: =>
    @state.provider.fields?.filter(@_fieldOnCurrentPage)
    .map (field, idx) =>
      errclass = if field.name in @state.errorFieldNames then "error " else ""
      <label className={(field.className || "")} key={field.name}>
        {field.label}
        <input type={field.type}
           tabIndex={idx + 1}
           value={@state.fields[field.name]}
           onChange={@_onValueChanged}
           onKeyPress={@_onFieldKeyPress}
           data-field={field.name}
           data-format={field.format ? ""}
           disabled={@state.tryingToAuthenticate}
           className={errclass}
           placeholder={field.placeholder} />
      </label>

  _renderSettings: =>
    @state.provider.settings?.filter(@_fieldOnCurrentPage)
    .map (field, idx) =>
      if field.type is 'checkbox'
        <label className={"checkbox #{field.className ? ""}"} key={field.name}>
          <input type={field.type}
             tabIndex={idx + 5}
             checked={@state.settings[field.name]}
             onChange={@_onSettingsChanged}
             onKeyPress={@_onFieldKeyPress}
             data-field={field.name}
             disabled={@state.tryingToAuthenticate}
             data-format={field.format ? ""}
             className={field.className ? ""} />
          {field.label}
        </label>
      else
        errclass = if field.name in @state.errorFieldNames then "error " else ""
        <label className={field.className ? ""}
           style={if field.advanced and not @state.show_advanced then {display:'none'} else {}}
           key={field.name}>
          {field.label}
          <input type={field.type}
             tabIndex={idx + 5}
             value={@state.settings[field.name]}
             onChange={@_onSettingsChanged}
             onKeyPress={@_onFieldKeyPress}
             data-field={field.name}
             data-format={field.format ? ""}
             disabled={@state.tryingToAuthenticate}
             className={errclass+(field.className ? "")}
             placeholder={field.placeholder} />
        </label>

  _renderButton: =>
    pages = @state.provider.pages || []
    if pages.length > @state.pageNumber+1
      <button className="btn btn-large btn-gradient" type="button" onClick={@_onNextButton}>Continue</button>
    else if @state.provider.name isnt 'gmail'
      if @state.tryingToAuthenticate
        <button className="btn btn-large btn-disabled btn-add-account-spinning" type="button">
          <RetinaImg name="sending-spinner.gif" width={15} height={15} mode={RetinaImg.Mode.ContentPreserve} /> Adding account&hellip;
        </button>
      else
        <button className="btn btn-large btn-gradient btn-add-account" type="button" onClick={@_onSubmit}>Add account</button>

  _onNextButton: (event) =>
    @setState(pageNumber: @state.pageNumber + 1)
    @_resize()

  _onSubmit: (event) =>
    return if @state.tryingToAuthenticate

    data = settings: {}
    for own k,v of @state.fields when v isnt ''
      data[k] = v
    for own k,v of @state.settings when v isnt ''
      data.settings[k] = v
    data.provider = @state.provider.name

    # handle special case for exchange/outlook/hotmail username field
    if data.provider in ['exchange','outlook','hotmail'] and not data.settings.username?.trim().length
      data.settings.username = data.email

    @setState(tryingToAuthenticate: true)

    # Send the form data directly to Nylas to get code
    # If this succeeds, send the received code to N1 server to register the account
    # Otherwise process the error message from the server and highlight UI as needed
    NylasAPI.makeRequest
      path: "/auth?client_id=#{NylasAPI.AppID}"
      method: 'POST'
      body: data
      returnsModel: false
      timeout: 30000
      auth:
        user: ''
        pass: ''
        sendImmediately: true
    .then (json) =>
      json.invite_code = atom.config.get('edgehill.token')
      json.email = data.email
      EdgehillAPI.request
        path: "/connect/nylas"
        method: "POST"
        body: json
        success: (json) =>
          OnboardingActions.accountJSONReceived(json)
        error: @_onNetworkError
    .catch(@_onNetworkError)

  _onNetworkError: (err) =>
    errorMessage = err.message
    if errorMessage == "Invite code required"
      choice = dialog.showMessageBox(
            remote.getCurrentWindow(),
            {
                type: 'info',
                buttons: ['Okay'],
                title: 'Confirm',
                message: 'Due to a large number of sign-ups this week, you’ll need an invitation code to add another account! Visit http://invite.nylas.com/ to grab one, or hold tight!'
            });
      OnboardingActions.moveToPage("token-auth")
    if errorMessage == "Invalid invite code"
      # delay?
      OnboardingActions.moveToPage("token-auth")
    pageNumber = @state.pageNumber
    errorFieldNames = err.body?.missing_fields || err.body?.missing_settings

    if errorFieldNames
      {pageNumber, errorMessage} = @_stateForMissingFieldNames(errorFieldNames)
    if err.statusCode is -123 # timeout
      errorMessage = "Request timed out. Please try again."

    @setState
      pageNumber: pageNumber
      errorMessage: errorMessage
      errorFieldNames: errorFieldNames || []
      tryingToAuthenticate: false
    @_resize()

  _stateForMissingFieldNames: (fieldNames) ->
    fieldLabels = []
    fields = [].concat(@state.provider.settings, @state.provider.fields)
    pageNumbers = [@state.pageNumber]

    for fieldName in fieldNames
      for s in fields when s.name is fieldName
        fieldLabels.push(s.label.toLowerCase())
        if s.page isnt undefined
          pageNumbers.push(s.page)

    pageNumber = Math.min.apply(null, pageNumbers)
    errorMessage = @_messageForFieldLabels(fieldLabels)

    {pageNumber, errorMessage}

  _messageForFieldLabels: (labels) ->
    if labels.length > 2
      return "Please fix the highlighted fields."
    else if labels.length is 2
      return "Please provide your #{labels[0]} and #{labels[1]}."
    else
      return "Please provide your #{labels[0]}."

  _pollForGmailAccount: (callback) =>
    EdgehillAPI.request
      path: "/oauth/google/token?key="+@state.provider.clientKey
      method: "GET"
      success: (json) =>
        callback(json)
      error: (err) =>
        callback()

  _resize: =>
    setTimeout( =>
      @props.onResize?()
    ,10)

  _fireMoveToPrevPage: =>
    if @state.pageNumber > 0
      @setState(pageNumber: @state.pageNumber-1)
      @_resize()
    else
      OnboardingActions.moveToPreviousPage()

module.exports = AccountSettingsPage
