import React, {Component, PropTypes} from 'react'
import ReactDOM from 'react-dom'
import classnames from 'classnames'
import Menu from './menu'
import RetinaImg from './retina-img'
import KeyCommandsRegion from './key-commands-region'


class SearchBar extends Component {
  static displayName = 'SearchBar';

  static propTypes = {
    className: PropTypes.string,
    query: PropTypes.string,
    isSearching: PropTypes.bool,
    placeholder: PropTypes.string,
    inputProps: PropTypes.object,
    suggestions: PropTypes.array,
    suggestionRenderer: PropTypes.func,
    suggestionKey: PropTypes.func,
    onClearSearchQuery: PropTypes.func,
    onClearSearchSuggestions: PropTypes.func,
    onSearchQueryChanged: PropTypes.func,
    onSubmitSearchQuery: PropTypes.func,
    onSelectSuggestion: PropTypes.func,
  }

  static defaultProps = {
    query: '',
    className: '',
    isSearching: false,
    inputProps: {},
    placeholder: 'Search',
    onSubmitSearchQuery: () => {},
  }

  componentDidMount() {
    this._mounted = true;
  }

  componentWillUnmount() {
    this._mounted = false;
  }

  clearAndBlur() {
    const {onClearSearchQuery} = this.props
    onClearSearchQuery()

    const inputEl = ReactDOM.findDOMNode(this.refs.searchInput);
    if (inputEl) {
      inputEl.blur();
    }
  }

  _onFocusSearch = () => {
    ReactDOM.findDOMNode(this.refs.searchInput).focus();
  }

  _onInputKeyDown = (event) => {
    const {key, target: {value}} = event;
    if (value.length > 0 && key === 'Escape') {
      this.clearAndBlur();
    }
  }

  _onInputChange = (event) => {
    const {onSearchQueryChanged} = this.props
    onSearchQueryChanged(event.target.value);
  }

  _onInputBlur = () => {
    // Don't immediately hide the menu when the text input is blurred,
    // because the user might have clicked an item in the menu. Wait to
    // handle the touch event, then dismiss the menu.
    setTimeout(() => {
      if (!this._mounted) { return; }
      const {onClearSearchSuggestions} = this.props
      onClearSearchSuggestions()
    }, 150);
  }

  renderSuggestion = (item) => {
    if (item.divider) {
      return <Menu.Item divider={item.divider} key={item.divider} />;
    }
    const {suggestionRenderer} = this.props
    if (suggestionRenderer) {
      return suggestionRenderer(item)
    }
    return item.label || '';
  }

  render() {
    const {
      query,
      className,
      inputProps,
      isSearching,
      suggestions,
      placeholder,
      suggestionKey,
      onSelectSuggestion,
      onSubmitSearchQuery,
      onClearSearchQuery,
    } = this.props

    const inputClass = classnames({
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
        onClick={() => onSubmitSearchQuery(query)}
      />
    );

    const headerComponents = [
      <input
        ref="searchInput"
        type="text"
        key="input"
        className={inputClass}
        placeholder={placeholder}
        value={query}
        onBlur={this._onInputBlur}
        onChange={this._onInputChange}
        onKeyDown={this._onInputKeyDown}
        {...inputProps}
      />,
      loupeImg,
      <RetinaImg
        className="search-accessory clear"
        name="searchclear.png"
        key="clear"
        mode={RetinaImg.Mode.ContentDark}
        onClick={onClearSearchQuery}
      />,
    ]


    return (
      <KeyCommandsRegion
        className={`nylas-search-bar ${className}`}
        globalHandlers={{
          'core:focus-search': this._onFocusSearch,
        }}
      >
        <div>
          <Menu
            ref="menu"
            className={classnames({
              'showing-query': query && query.length > 0,
              'search-container': true,
              'showing-suggestions': suggestions && suggestions.length > 0,
            })}
            headerComponents={headerComponents}
            items={suggestions}
            itemKey={suggestionKey}
            itemContent={this.renderSuggestion}
            onSelect={onSelectSuggestion}
          />
        </div>
      </KeyCommandsRegion>
    );
  }
}

export default SearchBar
