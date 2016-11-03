React = require 'react'
ReactCSSTransitionGroup = require 'react-addons-css-transition-group'
Sheet = require './sheet'
Toolbar = require './sheet-toolbar'
Flexbox = require('./components/flexbox').default
RetinaImg = require('./components/retina-img').default
InjectedComponentSet = require './components/injected-component-set'
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

  componentWillUnmount: =>
    @unsubscribe() if @unsubscribe

  render: =>
    totalSheets = @state.stack.length
    topSheet = @state.stack[totalSheets - 1]

    return <div></div> unless topSheet

    sheetElements = @_sheetElements()

    <Flexbox direction="column" className="layout-mode-#{@state.mode}" style={overflow: 'hidden'}>
      {@_toolbarContainerElement()}

      <div name="Header" style={order:1, zIndex: 2}>
        <InjectedComponentSet matching={locations: [topSheet.Header, WorkspaceStore.Sheet.Global.Header]}
                              direction="column"
                              id={topSheet.id}/>
      </div>

      <div name="Center" style={order:2, flex: 1, position:'relative', zIndex: 1}>
        {sheetElements[0]}
        <ReactCSSTransitionGroup transitionLeaveTimeout={125}
                                transitionEnterTimeout={125}
                                transitionName="sheet-stack">
          {sheetElements[1..-1]}
        </ReactCSSTransitionGroup>
      </div>

      <div name="Footer" style={order:3, zIndex: 4}>
        <InjectedComponentSet matching={locations: [topSheet.Footer, WorkspaceStore.Sheet.Global.Footer]}
                              direction="column"
                              id={topSheet.id}/>

      </div>
    </Flexbox>

  _toolbarContainerElement: =>
    {toolbar} = NylasEnv.getLoadSettings()
    return [] unless toolbar

    toolbarElements = @_toolbarElements()
    <div name="Toolbar" style={order:0, zIndex: 3} className="sheet-toolbar">
      {toolbarElements[0]}
      <ReactCSSTransitionGroup  transitionLeaveTimeout={125}
                               transitionEnterTimeout={125}
                               transitionName="opacity-125ms">
        {toolbarElements[1..-1]}
      </ReactCSSTransitionGroup>
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
    window.dispatchEvent(new Event('resize'))

  _onStoreChange: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    stack: WorkspaceStore.sheetStack()
    mode: WorkspaceStore.layoutMode()


module.exports = SheetContainer
