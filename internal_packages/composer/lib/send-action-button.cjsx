_ = require 'underscore'
_str = require 'underscore.string'
{React, Actions, ExtensionRegistry} = require 'nylas-exports'
{Menu, RetinaImg, ButtonDropdown} = require 'nylas-component-kit'

class SendActionButton extends React.Component
  @displayName: "SendActionButton"

  @propTypes:
    draft: React.PropTypes.object
    isValidDraft: React.PropTypes.func

  @CONFIG_KEY: "core.sending.defaultSendType"

  constructor: (@props) ->
    @state =
      actionConfigs: @_actionConfigs(@props)
      selectedSendType: NylasEnv.config.get(SendActionButton.CONFIG_KEY) ? @_defaultActionConfig().configKey

  componentDidMount: ->
    @unsub = ExtensionRegistry.Composer.listen(@_onExtensionsChanged)

  componentWillReceiveProps: (newProps) ->
    @setState actionConfigs: @_actionConfigs(newProps)

  componentWillUnmount: ->
    @unsub()

  primaryClick: => @_onPrimaryClick()

  _configKeyFromTitle: (title) ->
    return _str.dasherize(title.toLowerCase())

  _onExtensionsChanged: =>
    @setState actionConfigs: @_actionConfigs(@props)

  _defaultActionConfig: ->
    title: "Send"
    iconUrl: null
    onSend: ({draft}) -> Actions.sendDraft(draft.clientId)
    configKey: "send"

  _actionConfigs: (props) ->
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
        NylasEnv.emitError(err)

    return actionConfigs

  _verifyConfig: (config={}, extension) ->
    name = extension.name
    if not _.isString(config.title)
      throw new Error("#{name}.sendActionConfig must return a string `title`")

    if not _.isFunction(config.onSend)
      throw new Error("#{name}.sendActionConfig must return a `onSend` function that will be called when the action is selected")

    return true

  render: ->
    return false if not @props.draft
    if @state.actionConfigs.length is 1
      @_renderSingleDefaultButton()
    else
      @_renderSendDropdown()

  _onPrimaryClick: =>
    actionConfigs = @_orderedActionConfigs()
    @_sendWithAction(actionConfigs[0].onSend)

  _renderSingleDefaultButton: ->
    classes = "btn btn-toolbar btn-normal btn-emphasis btn-text btn-send"
    iconUrl = @state.actionConfigs[0].iconUrl
    <button className={classes}
            style={order: -100}
            onClick={@_onPrimaryClick}>{@_sendContent(iconUrl)}</button>

  _renderSendDropdown: ->
    actionConfigs = @_orderedActionConfigs()
    <ButtonDropdown
      className={"btn-send dropdown-btn-emphasis dropdown-btn-text"}
      style={order: -100}
      primaryItem={@_sendContent(actionConfigs[0].iconUrl)}
      primaryTitle={actionConfigs[0].title}
      primaryClick={@_onPrimaryClick}
      closeOnMenuClick={true}
      menu={@_dropdownMenu(actionConfigs[1..-1])}/>

  _orderedActionConfigs: ->
    configKeys = _.pluck(@state.actionConfigs, "configKey")
    if @state.selectedSendType not in configKeys
      selectedSendType = @_defaultActionConfig().configKey
    else
      selectedSendType = @state.selectedSendType

    primary = _.findWhere(@state.actionConfigs, configKey: selectedSendType)
    rest = _.reject @state.actionConfigs, (config) ->
      config.configKey is selectedSendType

    return [primary].concat(rest)

  _sendWithAction: (onSend) ->
    isValidDraft = @props.isValidDraft()
    if isValidDraft
      try
        onSend({draft: @props.draft})
      catch err
        NylasEnv.emitError(err)

  _dropdownMenu: (actionConfigs) ->
    <Menu items={actionConfigs}
          itemKey={ (actionConfig) -> actionConfig.configKey }
          itemContent={ (actionConfig) => @_sendContent(actionConfig.iconUrl) }
          onSelect={@_menuItemSelect}
          />

  _menuItemSelect: (actionConfig) =>
    @setState selectedSendType: actionConfig.configKey

  _sendContent: (iconUrl) ->
    sendIcon = "icon-composer-send.png"

    if iconUrl
      plusHTML = <span>&nbsp;+&nbsp;</span>
      additionalImg = <RetinaImg url={iconUrl}
                                 mode={RetinaImg.Mode.ContentIsMask} />
    else
      plusHTML = ""
      additionalImg = ""

    <span>
      <RetinaImg name={sendIcon} mode={RetinaImg.Mode.ContentIsMask} />
      <span className="text">Send{plusHTML}</span>{additionalImg}
    </span>

module.exports = SendActionButton
