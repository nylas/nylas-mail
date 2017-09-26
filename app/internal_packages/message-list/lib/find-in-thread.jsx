import React from 'react';
import classnames from 'classnames';
import { Actions, MessageStore, SearchableComponentStore } from 'mailspring-exports';
import { RetinaImg, KeyCommandsRegion } from 'mailspring-component-kit';

export default class FindInThread extends React.Component {
  static displayName = 'FindInThread';

  constructor(props) {
    super(props);
    this.state = SearchableComponentStore.getCurrentSearchData();
  }

  componentDidMount() {
    this._usub = SearchableComponentStore.listen(this._onSearchableChange);
  }

  componentWillUnmount() {
    this._usub();
  }

  _globalKeymapHandlers() {
    return {
      'core:find-in-thread': this._onFindInThread,
      'core:find-in-thread-next': this._onNextResult,
      'core:find-in-thread-previous': this._onPrevResult,
    };
  }

  _onFindInThread = () => {
    if (this.state.searchTerm === null) {
      Actions.findInThread('');
      if (MessageStore.hasCollapsedItems()) {
        Actions.toggleAllMessagesExpanded();
      }
    }
    this._focusSearch();
  };

  _onSearchableChange = () => {
    this.setState(SearchableComponentStore.getCurrentSearchData());
  };

  _onFindChange = event => {
    Actions.findInThread(event.target.value);
  };

  _onFindKeyDown = event => {
    if (event.key === 'Enter') {
      return event.shiftKey ? this._onPrevResult() : this._onNextResult();
    } else if (event.key === 'Escape') {
      this._clearSearch();
      this._searchBoxEl.blur();
    }
    return null;
  };

  _selectionText() {
    if (this.state.globalIndex !== null && this.state.resultsLength > 0) {
      return `${this.state.globalIndex + 1} of ${this.state.resultsLength}`;
    }
    return '';
  }

  _navEnabled() {
    return this.state.resultsLength > 0;
  }

  _onPrevResult = () => {
    if (this._navEnabled()) {
      Actions.previousSearchResult();
    }
  };

  _onNextResult = () => {
    if (this._navEnabled()) {
      Actions.nextSearchResult();
    }
  };

  _clearSearch = () => {
    Actions.findInThread(null);
  };

  _focusSearch = event => {
    if (!event || !(this._controlsWrapEl && this._controlsWrapEl.contains(event.target))) {
      this._searchBoxEl.focus();
    }
  };

  render() {
    const rootCls = classnames({
      'find-in-thread': true,
      enabled: this.state.searchTerm !== null,
    });
    const btnCls = 'btn btn-find-in-thread';
    return (
      <div className={rootCls} onClick={this._focusSearch}>
        <KeyCommandsRegion globalHandlers={this._globalKeymapHandlers()}>
          <div
            className="controls-wrap"
            ref={el => {
              this._controlsWrapEl = el;
            }}
          >
            <div className="input-wrap">
              <input
                type="text"
                ref={el => {
                  this._searchBoxEl = el;
                }}
                placeholder="Find in thread"
                onChange={this._onFindChange}
                onKeyDown={this._onFindKeyDown}
                value={this.state.searchTerm || ''}
              />

              <div className="selection-progress">{this._selectionText()}</div>

              <div className="btn-wrap">
                <button
                  tabIndex={-1}
                  className={btnCls}
                  disabled={!this._navEnabled()}
                  onClick={this._onPrevResult}
                >
                  <RetinaImg
                    name="ic-findinthread-previous.png"
                    mode={RetinaImg.Mode.ContentIsMask}
                  />
                </button>

                <button
                  className={btnCls}
                  tabIndex={-1}
                  disabled={!this._navEnabled()}
                  onClick={this._onNextResult}
                >
                  <RetinaImg name="ic-findinthread-next.png" mode={RetinaImg.Mode.ContentIsMask} />
                </button>
              </div>
            </div>

            <button className={btnCls} onClick={this._clearSearch}>
              <RetinaImg name="ic-findinthread-close.png" mode={RetinaImg.Mode.ContentIsMask} />
            </button>
          </div>
        </KeyCommandsRegion>
      </div>
    );
  }
}
