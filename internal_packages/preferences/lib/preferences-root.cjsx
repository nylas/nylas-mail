React = require 'react'
_ = require 'underscore'
{RetinaImg,
 Flexbox,
 ConfigPropContainer,
 ScrollRegion,
 KeyCommandsRegion}  = require 'nylas-component-kit'
{PreferencesUIStore} = require 'nylas-exports'

PreferencesSidebar = require './preferences-sidebar'

class PreferencesRoot extends React.Component
  @displayName: 'PreferencesRoot'
  @containerRequired: false

  constructor: (@props) ->
    @state = @getStateFromStores()

  componentDidMount: =>
    React.findDOMNode(@).focus()
    @unlisteners = []
    @unlisteners.push PreferencesUIStore.listen =>
      @setState(@getStateFromStores())
    @_focusContent()

  componentDidUpdate: =>
    @_focusContent()

  componentWillUnmount: =>
    unlisten() for unlisten in @unlisteners

  _localHandlers: ->
    stopPropagation = (e) -> e.stopPropagation()
    # This prevents some basic commands from propagating to the threads list and
    # producing unexpected results
    #
    # TODO This is a partial/temporary solution and should go away when we do the
    # Keymap/Commands/Menu refactor
    return {
      'core:next-item': stopPropagation
      'core:previous-item': stopPropagation
      'core:select-up': stopPropagation
      'core:select-down': stopPropagation
      'core:select-item': stopPropagation
      'core:remove-from-view': stopPropagation
      'core:messages-page-up': stopPropagation
      'core:messages-page-down': stopPropagation
      'core:list-page-up': stopPropagation
      'core:list-page-down': stopPropagation
      'application:archive-item': stopPropagation
      'application:delete-item': stopPropagation
      'application:print-thread': stopPropagation
    }

  getStateFromStores: =>
    tabs: PreferencesUIStore.tabs()
    selection: PreferencesUIStore.selection()

  render: =>
    tabId = @state.selection.get('tabId')
    tab = @state.tabs.find (s) => s.tabId is tabId

    if tab
      bodyElement = <tab.component accountId={@state.selection.get('accountId')} />
    else
      bodyElement = <div></div>

    <KeyCommandsRegion className="preferences-wrap" tabIndex="1" localHandlers={@_localHandlers()}>
      <Flexbox direction="row">
        <PreferencesSidebar tabs={@state.tabs}
                            selection={@state.selection} />
        <ScrollRegion className="preferences-content">
          <ConfigPropContainer ref="content">
            {bodyElement}
          </ConfigPropContainer>
        </ScrollRegion>
      </Flexbox>
    </KeyCommandsRegion>

  # Focus the first thing with a tabindex when we update.
  # inside the content area. This makes it way easier to interact with prefs.
  _focusContent: =>
    React.findDOMNode(@refs.content).querySelector('[tabindex]')?.focus()


module.exports = PreferencesRoot
