React = require 'react'

ipc = require 'ipc'
{RetinaImg} = require 'nylas-component-kit'
{EdgehillAPI, NylasAPI, APIError} = require 'nylas-exports'

Page = require './page'
OnboardingActions = require './onboarding-actions'
NylasApiEnvironmentStore = require './nylas-api-environment-store'
Providers = require './account-types'

class AccountSettingsPage extends Page
  @displayName: "AccountSettingsPage"

  constructor: (@props) ->
    @state =
      provider: @props.pageData.provider
      settings: {}
      fields: {}
      pageNumber: 0
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
              OnboardingActions.nylasAccountReceived(account)
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
    settings = @state.settings
    if event.target.type is 'checkbox'
      settings[field] = event.target.checked
    else
      settings[field] = event.target.value
    @setState({settings})

  _onValueChanged: (event) =>
    field = event.target.dataset.field
    fields = @state.fields
    fields[field] = event.target.value
    @setState({fields})

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
    if @state.error
      <div className="errormsg">{@state.error.message ? ""}</div>

  _fieldOnCurrentPage: (field) =>
    !@state.provider.pages || field.page is @state.pageNumber

  _renderFields: =>
    @state.provider.fields?.filter(@_fieldOnCurrentPage)
    .map (field, idx) =>
      errclass = if field.name in (@state.error?.invalid_fields ? []) then "error " else ""
      <label className={(field.className || "")} key={field.name}>
        {field.label}
        <input type={field.type}
           tabIndex={idx + 1}
           value={@state.fields[field.name]}
           onChange={@_onValueChanged}
           data-field={field.name}
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
             data-field={field.name}
             className={field.className ? ""} />
          {field.label}
        </label>
      else
        errclass = if field.name in (@state.error?.invalid_settings ? []) then "error " else ""
        <label className={field.className ? ""}
           style={if field.advanced and not @state.show_advanced then {display:'none'} else {}}
           key={field.name}>
          {field.label}
          <input type={field.type}
             tabIndex={idx + 5}
             value={@state.settings[field.name]}
             onChange={@_onSettingsChanged}
             data-field={field.name}
             className={errclass+(field.className ? "")}
             placeholder={field.placeholder} />
        </label>

  _renderButton: =>
    pages = @state.provider.pages || []
    if pages.length > @state.pageNumber+1
      <button className="btn btn-large btn-gradient" type="button" onClick={@_onNextButton}>Next</button>
    else if @state.provider.name isnt 'gmail'
      <button className="btn btn-large btn-gradient" type="button" onClick={@_submit}>Set up account</button>

  _onNextButton: (event) =>
    @setState(pageNumber: @state.pageNumber+1)
    @_resize()

  _submit: (event) =>
    data = settings: {}
    for own k,v of @state.fields when v isnt ''
      data[k] = v
    for own k,v of @state.settings when v isnt ''
      data.settings[k] = v
    data.provider = @state.provider.name

    # handle special case for exchange/outlook username field
    if data.provider in ['exchange','outlook'] and not data.settings.username?.trim().length
      data.settings.username = data.email

    # Send the form data directly to Nylas to get code
    # If this succeeds, send the received code to Edgehill server to register the account
    # Otherwise process the error message from the server and highlight UI as needed
    NylasAPI.makeRequest
      path: "/auth?client_id=#{NylasAPI.AppID}"
      method: 'POST'
      body: data
      returnsModel: false
      auth:
        user: ''
        pass: ''
        sendImmediately: true
    .then (json) =>
      EdgehillAPI.request
        path: "/connect/nylas"
        method: "POST"
        body: json
        success: (json) =>
          OnboardingActions.nylasAccountReceived(json)
        error: (err) =>
          throw err
    .catch APIError, (err) =>
      err_page_numbers = [@state.pageNumber]

      if err.body.missing_fields?
        err.body.invalid_fields = err.body.missing_fields

        missing_fields = []
        for missing in err.body.missing_fields
          for f in @state.provider.fields when f.name is missing
            missing_fields.push(f.label.toLowerCase())
            if f.page isnt undefined
              err_page_numbers.push(f.page)

        err.body.message = @_missing_fields_message(missing_fields)

      else if err.body.missing_settings?
        err.body.invalid_settings = err.body.missing_settings

        missing_settings = []
        for missing in err.body.missing_settings
          for s in @state.provider.settings when s.name is missing
            missing_settings.push(s.label.toLowerCase())
            if s.page isnt undefined
              err_page_numbers.push(s.page)

        err.body.message = @_missing_fields_message(missing_settings)

      console.log(Math.min.apply(err_page_numbers), err_page_numbers)
      @setState(error: err.body, pageNumber: Math.min.apply(null,err_page_numbers))
      @_resize()
      console.log(err)

  _missing_fields_message: (missing_settings) ->
    if missing_settings.length > 2
      return "Please fix the highlighted fields."
    else if missing_settings.length is 2
      first = missing_settings[0]
      last = missing_settings[1]
      return "Please provide your #{first} and #{last}."
    else
      setting = missing_settings[0]
      return "Please provide your #{setting}."

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
