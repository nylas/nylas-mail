React = require 'react/addons'
Sheet = require './sheet'
Toolbar = require './sheet-toolbar'
Flexbox = require './components/flexbox'
RetinaImg = require './components/retina-img'
InjectedComponentSet = require './components/injected-component-set'
TimeoutTransitionGroup = require './components/timeout-transition-group'
_ = require 'underscore'

{Actions,
 ComponentRegistry,
 WorkspaceStore} = require "nylas-exports"

class SheetContainer extends React.Component
  displayName = 'SheetContainer'

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @unsubscribe = WorkspaceStore.listen @_onStoreChange

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: =>
    @unsubscribe() if @unsubscribe

  render: =>
    totalSheets = @state.stack.length
    topSheet = @state.stack[totalSheets - 1]

    return <div></div> unless topSheet

    sheetElements = @_sheetElements()

    <Flexbox direction="column">
      {@_toolbarContainerElement()}
      
      <div name="Header" style={order:1, zIndex: 2}>
        <InjectedComponentSet matching={locations: [topSheet.Header, WorkspaceStore.Sheet.Global.Header]}
                              direction="column"
                              id={topSheet.id}/>
      </div>

      <div name="Center" style={order:2, flex: 1, position:'relative', zIndex: 1}>
        {sheetElements[0]}
        <TimeoutTransitionGroup leaveTimeout={125}
                                enterTimeout={125}
                                transitionName="sheet-stack">
          {sheetElements[1..-1]}
        </TimeoutTransitionGroup>
      </div>

      <div name="Footer" style={order:3, zIndex: 4}>
        <InjectedComponentSet matching={locations: [topSheet.Footer, WorkspaceStore.Sheet.Global.Footer]}
                              direction="column"
                              id={topSheet.id}/>
      </div>
    </Flexbox>

  _toolbarContainerElement: =>
    {toolbar} = atom.getLoadSettings()
    return [] unless toolbar

    toolbarElements = @_toolbarElements()
    <div name="Toolbar" style={order:0, zIndex: 3} className="sheet-toolbar">
      {toolbarElements[0]}
      <TimeoutTransitionGroup  leaveTimeout={125}
                               enterTimeout={125}
                               transitionName="sheet-toolbar">
        {toolbarElements[1..-1]}
      </TimeoutTransitionGroup>
    </div>

  _toolbarElements: =>
    @state.stack.map (sheet, index) ->
      <Toolbar data={sheet}
               ref={"toolbar-#{index}"}
               key={"#{index}:#{sheet.id}:toolbar"}
               depth={index} />

  _sheetElements: =>
    @state.stack.map (sheet, index) =>
      <Sheet data={sheet}
             depth={index}
             key={"#{index}:#{sheet.id}"}
             onColumnSizeChanged={@_onColumnSizeChanged} />

  _onColumnSizeChanged: (sheet) =>
    @refs["toolbar-#{sheet.props.depth}"]?.recomputeLayout()

  _onStoreChange: =>
    _.defer => @setState(@_getStateFromStores())

  _getStateFromStores: =>
    stack: WorkspaceStore.sheetStack()


module.exports = SheetContainer