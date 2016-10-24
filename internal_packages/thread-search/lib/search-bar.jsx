import React from 'react'
import ReactDOM from 'react-dom'
import classNames from 'classnames'

import {WorkspaceStore} from 'nylas-exports'
import {Menu, RetinaImg, KeyCommandsRegion} from 'nylas-component-kit'

import SearchStore from './search-store'
import SearchActions from './search-actions'

export default class SearchBar extends React.Component {
  static displayName = 'SearchBar';

  constructor(props) {
    super(props);
    this.state = Object.assign({}, this._getStateFromStores(), {
      focused: false,
    });
  }

  componentDidMount() {
    this._mounted = true;
    this._unsubscribes = [
      SearchStore.listen(this._onChange),
      WorkspaceStore.listen(() => {
        if (this.state.focused) {
          this.setState({focused: false});
        }
      }),
    ];
  }

  // It's important that every React class explicitly stops listening to
  // N1 events before it unmounts. Thank you event-kit
  // This can be fixed via a Reflux mixin
  componentWillUnmount() {
    this._mounted = false;
    for (const usub of this._unsubscribes) {
      usub();
    }
  }

  _onFocusSearch = () => {
    ReactDOM.findDOMNode(this.refs.searchInput).focus();
  }

  _onValueChange = (event) => {
    SearchActions.queryChanged(event.target.value);
    if (event.target.value === '') {
      this._onClearSearch();
    }
  }

  _onSelectSuggestion = (item) => {
    if (item.thread) {
      SearchActions.querySubmitted(`"${item.thread.subject}"`)
    } else {
      SearchActions.querySubmitted(item.value);
    }
  }

  _onClearSearch = () => {
    SearchActions.querySubmitted("");
  }

  _onClearAndBlur = () => {
    this._onClearSearch();
    const inputEl = ReactDOM.findDOMNode(this.refs.searchInput);
    if (inputEl) {
      inputEl.blur();
    }
  }

  _onFocus = () => {
    this.setState({focused: true});
  }

  _onBlur = () => {
    // Don't immediately hide the menu when the text input is blurred,
    // because the user might have clicked an item in the menu. Wait to
    // handle the touch event, then dismiss the menu.
    setTimeout(() => {
      if (!this._mounted) {
        return;
      }
      SearchActions.searchBlurred();
      this.setState({focused: false});
    }, 150);
  }

  _doSearch = () => {
    SearchActions.querySubmitted(this.state.query);
  }

  _onChange = () => {
    this.setState(this._getStateFromStores())
  }

  _getStateFromStores() {
    return {
      query: SearchStore.query(),
      suggestions: SearchStore.suggestions(),
      isSearching: SearchStore.isSearching(),
    };
  }

  render() {
    const {focused, isSearching, query, suggestions} = this.state;

    const inputClass = classNames({
      empty: query.length === 0,
    });

    const loupeImg = isSearching ? (
      <RetinaImg
        className="search-accessory search loading"
        name="inline-loading-spinner.gif"
        key="accessory"
        mode={RetinaImg.Mode.ContentPreserve}
      />
    ) : (
      <RetinaImg
        className="search-accessory search"
        name="searchloupe.png"
        key="accessory"
        mode={RetinaImg.Mode.ContentDark}
        onClick={this._doSearch}
      />
    );

    const headerComponents = [
      <input
        type="text"
        ref="searchInput"
        key="input"
        className={inputClass}
        placeholder="Search all email"
        value={query}
        onChange={this._onValueChange}
        onFocus={this._onFocus}
        onBlur={this._onBlur}
      />,
      loupeImg,
      <RetinaImg
        className="search-accessory clear"
        name="searchclear.png"
        key="clear"
        mode={RetinaImg.Mode.ContentDark}
        onClick={this._onClearSearch}
      />,
    ]

    const itemContentFunc = (item) => {
      if (item.divider) {
        return (<Menu.Item divider={item.divider} key={item.divider} />);
      }
      if (item.contact) {
        return (<Menu.NameEmailItem name={item.contact.name} email={item.contact.email} />);
      }
      if (item.thread) {
        return item.thread.subject;
      }
      return item.label;
    }

    return (
      <KeyCommandsRegion
        className="search-bar"
        globalHandlers={{
          'core:focus-search': this._onFocusSearch,
          'search-bar:escape-search': this._onClearAndBlur,
        }}
      >
        <div>
          <Menu
            ref="menu"
            className={classNames({
              'focused': focused,
              'showing-query': query && query.length > 0,
              'search-container': true,
              'showing-suggestions': suggestions && suggestions.length > 0,
            })}
            headerComponents={headerComponents}
            items={suggestions}
            itemContent={itemContentFunc}
            itemKey={(item) => item.label || (item.contact || {}).id || (item.thread || {}).id}
            onSelect={this._onSelectSuggestion}
          />
        </div>
      </KeyCommandsRegion>
    );
  }
}
