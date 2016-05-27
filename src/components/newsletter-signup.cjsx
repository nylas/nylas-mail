_ = require 'underscore'
request = require 'request'
React = require 'react'
{Utils, EdgehillAPI} = require "nylas-exports"
{RetinaImg, Flexbox} = require 'nylas-component-kit'

class NewsletterSignup extends React.Component
  @displayName: 'NewsletterSignup'
  @propTypes:
    name: React.PropTypes.string
    emailAddress: React.PropTypes.string

  constructor: (@props) ->
    @state = {status: 'Pending'}

  componentWillReceiveProps: (nextProps) =>
    @_onGetStatus(nextProps) if not _.isEqual(@props, nextProps)

  componentDidMount: =>
    @_mounted = true
    @_onGetStatus()

  componentWillUnmount: =>
    @_mounted = false

  _setState: (state) =>
    return unless @_mounted
    @setState(state)

  _onGetStatus: (props = @props) =>
    @_setState({status: 'Pending'})
    EdgehillAPI.makeRequest
      method: 'GET'
      path: @_path(props)
      success: (status) =>
        if status is 'Never Subscribed'
          @_onSubscribe()
        else
          @_setState({status})
      error: =>
        @_setState({status: "Error"})

  _onSubscribe: =>
    @_setState({status: 'Pending'})
    EdgehillAPI.makeRequest
      method: 'POST'
      path: @_path()
      success: (status) =>
        @_setState({status})
      error: =>
        @_setState({status: "Error"})

  _onUnsubscribe: =>
    @_setState({status: 'Pending'})
    EdgehillAPI.makeRequest
      method: 'DELETE'
      path: @_path()
      success: (status) =>
        @_setState({status})
      error: =>
        @_setState({status: "Error"})

  _path: (props = @props) =>
    "/newsletter-subscription/#{encodeURIComponent(props.emailAddress)}?name=#{encodeURIComponent(props.name)}"

  render: =>
    <Flexbox direction='row' height='auto' style={textAlign: 'left'}>
      <div style={minWidth:15}>
        {@_renderControl()}
      </div>
      <label htmlFor="subscribe-check" style={paddingLeft: 4, flex: 1}>
        Notify me about new features and plugins via this email address.
      </label>
    </Flexbox>

  _renderControl: ->
    if @state.status is 'Pending'
      <RetinaImg name='inline-loading-spinner.gif' mode={RetinaImg.Mode.ContentDark} style={width:14, height:14}/>
    else if @state.status is 'Error'
      <button onClick={@_onGetStatus} className="btn">Retry</button>
    else if @state.status in ['Subscribed', 'Active']
      <input id="subscribe-check" type="checkbox" checked={true} style={marginTop:3} onChange={@_onUnsubscribe} />
    else
      <input id="subscribe-check" type="checkbox" checked={false} style={marginTop:3} onChange={@_onSubscribe} />

module.exports = NewsletterSignup
