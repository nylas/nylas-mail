import React from 'react'
import ReactDOM from 'react-dom'
import classnames from 'classnames'
import {Actions, MessageStore, SearchableComponentStore} from 'nylas-exports'
import {RetinaImg, KeyCommandsRegion} from 'nylas-component-kit'

export default class FindInThread extends React.Component {
  static displayName = "FindInThread";

  constructor(props) {
    super(props);
    this.state = SearchableComponentStore.getCurrentSearchData()
  }

  componentDidMount() {
    this._usub = SearchableComponentStore.listen(this._onSearchableChange)
  }

  componentWillUnmount() {
    this._usub()
  }

  _globalKeymapHandlers() {
    return {
      'application:find-in-thread': this._onFindInThread,
      'application:find-in-thread-next': this._onNextResult,
      'application:find-in-thread-previous': this._onPrevResult,
    }
  }

  _onFindInThread = () => {
    if (this.state.searchTerm === null) {
      Actions.findInThread("");
      if (MessageStore.hasCollapsedItems()) {
        Actions.toggleAllMessagesExpanded()
      }
    }
    this._focusSearch()
  }

  _onSearchableChange = () => {
    this.setState(SearchableComponentStore.getCurrentSearchData())
  }

  _onFindChange = (event) => {
    Actions.findInThread(event.target.value)
  }

  _onFindKeyDown = (event) => {
    if (event.key === "Enter") {
      return event.shiftKey ? this._onPrevResult() : this._onNextResult()
    } else if (event.key === "Escape") {
      this._clearSearch()
      ReactDOM.findDOMNode(this.refs.searchBox).blur()
    }
  }

  _selectionText() {
    if (this.state.globalIndex !== null && this.state.resultsLength > 0) {
      return `${this.state.globalIndex + 1} of ${this.state.resultsLength}`
    }
    return ""
  }

  _navEnabled() {
    return this.state.resultsLength > 0;
  }

  _onPrevResult = () => {
    if (this._navEnabled()) { Actions.previousSearchResult() }
  }

  _onNextResult = () => {
    if (this._navEnabled()) { Actions.nextSearchResult() }
  }

  _clearSearch = () => {
    Actions.findInThread(null)
  }

  _focusSearch = (event) => {
    const cw = ReactDOM.findDOMNode(this.refs.controlsWrap)
    if (!event || !(cw && cw.contains(event.target))) {
      ReactDOM.findDOMNode(this.refs.searchBox).focus()
    }
  }

  render() {
    const rootCls = classnames({
      "find-in-thread": true,
      "enabled": this.state.searchTerm !== null,
    })
    const btnCls = "btn btn-find-in-thread";
    return (
      <div className={rootCls} onClick={this._focusSearch}>
        <KeyCommandsRegion globalHandlers={this._globalKeymapHandlers()}>
        <div className="controls-wrap" ref="controlsWrap">
          <div className="input-wrap">

            <input type="text"
                   ref="searchBox"
                   placeholder="Find in thread"
                   onChange={this._onFindChange}
                   onKeyDown={this._onFindKeyDown}
                   value={this.state.searchTerm || ""}/>

            <div className="selection-progress">{this._selectionText()}</div>

            <div className="btn-wrap">
              <button tabIndex={-1}
                      className={btnCls}
                      disabled={!this._navEnabled()}
                      onClick={this._onPrevResult}>
                <RetinaImg name="ic-findinthread-previous.png"
                           mode={RetinaImg.Mode.ContentIsMask}/>
              </button>

              <button className={btnCls}
                      tabIndex={-1}
                      disabled={!this._navEnabled()}
                      onClick={this._onNextResult}>
                <RetinaImg name="ic-findinthread-next.png"
                           mode={RetinaImg.Mode.ContentIsMask}/>
              </button>
            </div>

          </div>

          <button className={btnCls}
                  onClick={this._clearSearch}>
            <RetinaImg name="ic-findinthread-close.png"
                       mode={RetinaImg.Mode.ContentIsMask}/>
          </button>
        </div>
        </KeyCommandsRegion>
      </div>
    )
  }

}
