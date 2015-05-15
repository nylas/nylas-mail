_ = require 'underscore-plus'
React = require 'react'
{Actions, Message, DraftStore} = require 'nylas-exports'

class TemplateStatusBar extends React.Component
  @displayName: 'TemplateStatusBar'

  @containerStyles:
    textAlign:'center'
    width:530
    margin:'auto'

  @propTypes:
    draftLocalId: React.PropTypes.string

  constructor: (@props) ->
    @state = draft: null

  componentDidMount: =>
    DraftStore.sessionForLocalId(@props.draftLocalId).then (_proxy) =>
      return if @_unmounted
      return unless _proxy.draftLocalId is @props.draftLocalId
      @_proxy = _proxy
      @unsubscribe = @_proxy.listen(@_onDraftChange, @)
      @_onDraftChange()

  componentWillUnmount: =>
    @_unmounted = true
    @unsubscribe() if @unsubscribe

  render: =>
    if @_draftUsesTemplate()
      <div className="template-status-bar">
        Press "tab" to quickly fill in the blanks - highlighting will not be visible to recipients.
      </div>
    else
      <div></div>

  _onDraftChange: =>
    @setState(draft: @_proxy.draft())

  _draftUsesTemplate: =>
    return unless @state.draft
    @state.draft.body.search(/<code[^>]*class="var[^>]*>/i) > 0


module.exports = TemplateStatusBar
