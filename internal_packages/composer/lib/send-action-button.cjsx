_ = require 'underscore'
_str = require 'underscore.string'
{React, Actions, ExtensionRegistry} = require 'nylas-exports'
{Menu, RetinaImg, ButtonDropdown} = require 'nylas-component-kit'

class SendActionButton extends React.Component
  @displayName: "SendActionButton"

  @propTypes:
    draft: React.PropTypes.object
    style: React.PropTypes.object
    isValidDraft: React.PropTypes.func

  @defaultProps:
    style: {}

  @CONFIG_KEY: "core.sending.defaultSendType"

  constructor: (@props) ->
    @state =
      actionConfigs: @_actionConfigs(@props)

  componentDidMount: =>
    @unsub = ExtensionRegistry.Composer.listen(@_onExtensionsChanged)

  componentWillReceiveProps: (newProps) =>
    @setState actionConfigs: @_actionConfigs(newProps)

  componentWillUnmount: =>
    @unsub()

  primaryClick: => @_onPrimaryClick()

  _configKeyFromTitle: (title) =>
    return _str.dasherize(title.toLowerCase())

  _onExtensionsChanged: =>
    @setState actionConfigs: @_actionConfigs(@props)

  _defaultActionConfig: =>
    title: "Send"
    iconUrl: null
    onSend: ({draft}) -> Actions.sendDraft(draft.clientId)
    configKey: "send"

  _actionConfigs: (props) =>
    return [] unless props.draft
    actionConfigs = [@_defaultActionConfig()]

    for extension in ExtensionRegistry.Composer.extensions()
      try
        actionConfig = extension.sendActionConfig?({draft: props.draft})
        if actionConfig
          @_verifyConfig(actionConfig, extension)
          actionConfig.configKey = @_configKeyFromTitle(actionConfig.title)
          actionConfigs.push(actionConfig)
      catch err
        NylasEnv.reportError(err)

    return actionConfigs

  _verifyConfig: (config={}, extension) =>
    name = extension.name
    if not _.isString(config.title)
      throw new Error("#{name}.sendActionConfig must return a string `title`")

    if not _.isFunction(config.onSend)
      throw new Error("#{name}.sendActionConfig must return a `onSend` function that will be called when the action is selected")

    return true

  render: =>
    return false unless @props.draft
    if @state.actionConfigs.length is 1
      @_renderSingleDefaultButton()
    else
      @_renderSendDropdown()

  _onPrimaryClick: =>
    {preferred} = @_orderedActionConfigs()
    @_sendWithAction(preferred)

  _renderSingleDefaultButton: =>
    <button
      className={"btn btn-toolbar btn-normal btn-emphasis btn-text btn-send"}
      style={order: -100}
      onClick={@_onPrimaryClick}>
      {@_contentForAction(@state.actionConfigs[0])}
    </button>

  _renderSendDropdown: =>
    {preferred, rest} = @_orderedActionConfigs()

    <ButtonDropdown
      className={"btn-send btn-emphasis btn-text"}
      style={order: -100}
      primaryItem={@_contentForAction(preferred)}
      primaryTitle={preferred.title}
      primaryClick={@_onPrimaryClick}
      closeOnMenuClick={true}
      menu={@_dropdownMenu(rest)}/>

  _orderedActionConfigs: =>
    configKeys = _.pluck(@state.actionConfigs, "configKey")
    preferredKey = NylasEnv.config.get(SendActionButton.CONFIG_KEY)

    if not preferredKey? or preferredKey not in configKeys
      preferredKey = @_defaultActionConfig().configKey

    preferred = _.findWhere(@state.actionConfigs, configKey: preferredKey)
    rest = _.without(@state.actionConfigs, preferred)

    {preferred, rest}

  _sendWithAction: ({onSend}) =>
    isValidDraft = @props.isValidDraft()
    if isValidDraft
      try
        onSend({draft: @props.draft})
      catch err
        NylasEnv.reportError(err)

  _dropdownMenu: (actionConfigs) =>
    <Menu items={actionConfigs}
          itemKey={ (actionConfig) -> actionConfig.configKey }
          itemContent={@_contentForAction}
          onSelect={@_sendWithAction}
          />

  _contentForAction: ({iconUrl}) =>
    if iconUrl
      plusHTML = <span>&nbsp;+&nbsp;</span>
      additionalImg = <RetinaImg url={iconUrl}
                                 mode={RetinaImg.Mode.ContentIsMask} />
    else
      plusHTML = ""
      additionalImg = ""

    <span>
      <RetinaImg name="icon-composer-send.png" mode={RetinaImg.Mode.ContentIsMask} />
      <span className="text">Send{plusHTML}</span>{additionalImg}
    </span>

module.exports = SendActionButton
