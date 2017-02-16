import React, {Component, PropTypes} from 'react'
import {Menu, SearchBar, ListensToFluxStore} from 'nylas-component-kit'
import SearchStore from './search-store'
import SearchActions from './search-actions'


class ThreadSearchBar extends Component {
  static displayName = 'ThreadSearchBar';

  static propTypes = {
    query: PropTypes.string,
    isSearching: PropTypes.bool,
    suggestions: PropTypes.array,
  }

  _onSelectSuggestion = (suggestion) => {
    if (suggestion.thread) {
      SearchActions.querySubmitted(`"${suggestion.thread.subject}"`)
    } else {
      SearchActions.querySubmitted(suggestion.value);
    }
  }

  _onSearchQueryChanged = (query) => {
    SearchActions.queryChanged(query);
    if (query === '') {
      this._onClearSearchQuery();
    }
  }

  _onSubmitSearchQuery = (query) => {
    SearchActions.querySubmitted(query);
  }

  _onClearSearchQuery = () => {
    SearchActions.querySubmitted('');
  }

  _onClearSearchSuggestions = () => {
    SearchActions.searchBlurred()
  }

  _renderSuggestion = (suggestion) => {
    if (suggestion.contact) {
      return <Menu.NameEmailItem name={suggestion.contact.name} email={suggestion.contact.email} />;
    }
    if (suggestion.thread) {
      return suggestion.thread.subject;
    }
    if (suggestion.customElement) {
      return suggestion.customElement
    }
    return suggestion.label;
  }

  render() {
    const {query, isSearching, suggestions} = this.props;

    return (
      <SearchBar
        className="thread-search-bar"
        placeholder="Search all email"
        query={query}
        suggestions={suggestions}
        isSearching={isSearching}
        suggestionKey={(suggestion) => suggestion.label || (suggestion.contact || {}).id || (suggestion.thread || {}).id}
        suggestionRenderer={this._renderSuggestion}
        onSelectSuggestion={this._onSelectSuggestion}
        onSubmitSearchQuery={this._onSubmitSearchQuery}
        onSearchQueryChanged={this._onSearchQueryChanged}
        onClearSearchQuery={this._onClearSearchQuery}
        onClearSearchSuggestions={this._onClearSearchSuggestions}
      />
    )
  }
}

export default ListensToFluxStore(ThreadSearchBar, {
  stores: [SearchStore],
  getStateFromStores() {
    return {
      query: SearchStore.query(),
      suggestions: SearchStore.suggestions(),
      isSearching: SearchStore.isSearching(),
    };
  },
})
