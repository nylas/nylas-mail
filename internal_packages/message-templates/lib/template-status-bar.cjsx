_ = require 'underscore-plus'
React = require 'react'
{Actions, Message, DraftStore} = require 'inbox-exports'

class TemplateStatusBar extends React.Component
  @displayName: 'TemplateStatusBar'

  @propTypes:
    draftLocalId: React.PropTypes.string

  constructor: (@props) ->
    @state = draft: null

  componentDidMount: =>
    @_proxy = DraftStore.sessionForLocalId(@props.draftLocalId)
    @unsubscribe = @_proxy.listen(@_onDraftChange, @)
    if @_proxy.draft()
      @_onDraftChange()

  componentWillUnmount: =>
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
