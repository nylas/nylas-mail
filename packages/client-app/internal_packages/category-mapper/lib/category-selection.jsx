import {
  Menu,
  RetinaImg,
  DropdownMenu,
  LabelColorizer,
  BoldedSearchResult,
} from 'nylas-component-kit'
import {
  Utils,
  React,
} from 'nylas-exports'
import {Categories} from 'nylas-observables'

export default class CategorySelection extends React.Component {
  static propTypes = {
    account: React.PropTypes.object,
    currentCategory: React.PropTypes.string,
  }
  constructor(props) {
    super(props)
    this._categories = []
    this.state = {
      categoryData: this._recalculateCategories({searchValue: ''}),
      searchValue: "",
    }
  }

  componentDidMount() {
    this._disposable = Categories.forAccount(this.props.account).sort().subscribe(this._onCategoriesChanged)
  }

  shouldComponentUpdate(nextProps, nextState) {
    return !(Utils.isEqualReact(nextState, this.state) && Utils.isEqualReact(nextProps, this.props))
  }

  componentWillUnmount() {
    this._disposable.dispose()
  }

  _isInSearch = (searchValue, category) => {
    return Utils.wordSearchRegExp(searchValue).test(category.displayName)
  };

  _isUserFacing = (category) => {
    const hiddenCategories = ['N1-Snoozed', 'EI']
    return !hiddenCategories.includes(category.displayName)
  };

  _itemForCategory = (category) => {
    if (!category.divider) {
      category.backgroundColor = LabelColorizer.backgroundColorDark(category)
    }
    return category
  };

  _recalculateCategories = ({searchValue = this.state.searchValue} = {}) => {
    let categories = this._categories

    if (!this.props.account.usesLabels()) {
      const standardCategories = categories.filter((cat) => cat.isStandardCategory())
      const userCategories = categories.filter((cat) => cat.isUserCategory())
      categories = standardCategories
        .concat([{divider: true, id: "category-divider"}])
        .concat(userCategories)
    }

    const categoryData = categories
      .filter(this._isUserFacing)
      .filter(c => this._isInSearch(searchValue, c))
      .map(this._itemForCategory)

    return categoryData
  };

  _onCategoriesChanged = (categories) => {
    this._categories = categories
    this.setState({categoryData: this._recalculateCategories()})
  };

  _onSearchValueChange = (event) => {
    const searchValue = event.target.value;
    this.setState({
      searchValue,
      categoryData: this._recalculateCategories({searchValue}),
    })
  };

  _renderFolderIcon = (item) => {
    return (
      <RetinaImg
        name={`${item.name}.png`}
        fallback={'folder.png'}
        mode={RetinaImg.Mode.ContentIsMask}
      />
    )
  };

  _renderLabelIcon = (item) => {
    return (
      <RetinaImg
        name={`${item.name}.png`}
        fallback={'tag.png'}
        mode={RetinaImg.Mode.ContentIsMask}
      />
    )
  }

  _renderItem = (item = {empty: true}) => {
    if (item.divider) {
      return <Menu.Item key={item.id} divider={item.divider} />
    }

    let icon;
    if (item.empty) {
      icon = (<div className="empty-icon" />)
      item.displayName = "(None)"
    } else {
      icon = this.props.account.usesLabels() ? this._renderLabelIcon(item) : this._renderFolderIcon(item);
    }

    return (
      <div className="category-item">
        {icon}
        <div className="category-display-name">
          <BoldedSearchResult value={item.displayName} query={this.state.searchValue || ""} />
        </div>
      </div>
    )
  };

  render() {
    const placeholder = this.props.account.usesLabels() ? 'Choose folder or label' : 'Choose folder'

    const headerComponents = [
      <input
        type="text"
        tabIndex="-1"
        key="textfield"
        className="search"
        placeholder={placeholder}
        value={this.state.searchValue}
        onChange={this._onSearchValueChange}
      />,
    ]

    return (
      <div className="category-selection">
        <DropdownMenu
          intitialSelectionItem={this.props.currentCategory}
          headerComponents={headerComponents}
          footerComponents={[]}
          items={this.state.categoryData}
          itemKey={item => item.id}
          itemContent={this._renderItem}
          defaultSelectedIndex={this.state.searchValue === "" ? -1 : 0}
          {...this.props}
        />
      </div>
    )
  }
}
