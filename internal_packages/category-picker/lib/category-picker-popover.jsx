import _ from 'underscore'
import React, {Component, PropTypes} from 'react'
import {
  Menu,
  RetinaImg,
  LabelColorizer,
} from 'nylas-component-kit'
import {
  Utils,
  Actions,
  TaskQueueStatusStore,
  DatabaseStore,
  TaskFactory,
  Category,
  SyncbackCategoryTask,
  CategoryStore,
  FocusedPerspectiveStore,
} from 'nylas-exports'
import {Categories} from 'nylas-observables'


export default class CategoryPickerPopover extends Component {

  static propTypes = {
    threads: PropTypes.array.isRequired,
    account: PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props)
    this._categories = []
    this._standardCategories = []
    this._userCategories = []
    this.state = this._recalculateState(this.props, {searchValue: ''})
  }

  componentDidMount() {
    this._registerObservables()
  }

  componentWillReceiveProps(nextProps) {
    this._registerObservables(nextProps)
    this.setState(this._recalculateState(nextProps))
  }

  componentWillUnmount() {
    this._unregisterObservables()
  }

  _registerObservables = (props = this.props)=> {
    this._unregisterObservables()
    this.disposables = [
      Categories.forAccount(props.account).subscribe(this._onCategoriesChanged),
    ]
  };

  _unregisterObservables = ()=> {
    if (this.disposables) {
      this.disposables.forEach(disp => disp.dispose())
    }
  };

  _isInSearch = (searchValue, category)=> {
    return Utils.wordSearchRegExp(searchValue).test(category.displayName)
  };

  _isUserFacing = (allInInbox, category)=> {
    const currentCategories = FocusedPerspectiveStore.current().categories() || []
    const currentCategoryIds = _.pluck(currentCategories, 'id')
    const {account} = this.props
    let hiddenCategories = []

    if (account) {
      if (account.usesLabels()) {
        hiddenCategories = ["all", "drafts", "sent", "archive", "starred", "important", "N1-Snoozed"]
        if (allInInbox) {
          hiddenCategories.push("inbox")
        }
        if (category.divider) {
          return false
        }
      } else if (account.usesFolders()) {
        hiddenCategories = ["drafts", "sent", "N1-Snoozed"]
      }
    }
    return (
      (!hiddenCategories.includes(category.name)) &&
      (!hiddenCategories.includes(category.displayName)) &&
      (!currentCategoryIds.includes(category.id))
    )
  };

  _itemForCategory = ({usageCount, numThreads}, category)=> {
    if (category.divider) {
      return category
    }
    const item = category.toJSON()
    item.category = category
    item.backgroundColor = LabelColorizer.backgroundColorDark(category)
    item.usage = usageCount[category.id] || 0
    item.numThreads = numThreads
    return item
  };

  _allInInbox = (usageCount, numThreads)=> {
    const {account} = this.props
    const inbox = CategoryStore.getStandardCategory(account, "inbox")
    if (!inbox) return false
    return usageCount[inbox.id] === numThreads
  };

  _categoryUsageCount = (props) => {
    const {threads} = props
    const categoryUsageCount = {}
    _.flatten(_.pluck(threads, 'categories')).forEach((category)=> {
      categoryUsageCount[category.id] = categoryUsageCount[category.id] || 0
      categoryUsageCount[category.id] += 1
    })
    return categoryUsageCount;
  };

  _recalculateState = (props = this.props, {searchValue = (this.state.searchValue || "")} = {})=> {
    const {account, threads} = props

    const numThreads = threads.length
    let categories;

    if (numThreads === 0) {
      return {categoryData: [], searchValue}
    }

    if (account.usesLabels()) {
      categories = this._categories
    } else {
      categories = this._standardCategories
        .concat([{divider: true, id: "category-divider"}])
        .concat(this._userCategories)
    }

    const usageCount = this._categoryUsageCount(props, categories)
    const allInInbox = this._allInInbox(usageCount, numThreads)
    const displayData = {usageCount, numThreads}

    const categoryData = _.chain(categories)
      .filter(_.partial(this._isUserFacing, allInInbox))
      .filter(_.partial(this._isInSearch, searchValue))
      .map(_.partial(this._itemForCategory, displayData))
      .value()

    if (searchValue.length > 0) {
      const newItemData = {
        searchValue: searchValue,
        newCategoryItem: true,
        id: "category-create-new",
      }
      categoryData.push(newItemData)
    }
    return {categoryData, searchValue}
  };

  _onCategoriesChanged = (categories)=> {
    this._categories = categories
    this._standardCategories = categories.filter((cat) => cat.isStandardCategory())
    this._userCategories = categories.filter((cat) => cat.isUserCategory())
    this.setState(this._recalculateState())
  };

  _onSelectCategory = (item)=> {
    const {account, threads} = this.props

    if (threads.length === 0) return;
    this.refs.menu.setSelectedItem(null)

    if (item.newCategoryItem) {
      const category = new Category({
        displayName: this.state.searchValue,
        accountId: account.id,
      })
      const syncbackTask = new SyncbackCategoryTask({category})

      TaskQueueStatusStore.waitForPerformRemote(syncbackTask).then(()=> {
        DatabaseStore.findBy(category.constructor, {clientId: category.clientId})
        .then((cat) => {
          const applyTask = TaskFactory.taskForApplyingCategory({
            threads: threads,
            category: cat,
          })
          Actions.queueTask(applyTask)
        })
      })
      Actions.queueTask(syncbackTask)
    } else if (item.usage === threads.length) {
      const applyTask = TaskFactory.taskForRemovingCategory({
        threads: threads,
        category: item.category,
      })
      Actions.queueTask(applyTask)
    } else {
      const applyTask = TaskFactory.taskForApplyingCategory({
        threads: threads,
        category: item.category,
      })
      Actions.queueTask(applyTask)
    }
    Actions.closePopover()
  };

  _onSearchValueChange = (event)=> {
    this.setState(
      this._recalculateState(this.props, {searchValue: event.target.value})
    )
  };

  _renderBoldedSearchResults = (item)=> {
    const name = item.display_name
    const searchTerm = (this.state.searchValue || "").trim()

    if (searchTerm.length === 0) return name;

    const re = Utils.wordSearchRegExp(searchTerm)
    const parts = name.split(re).map((part) => {
      // The wordSearchRegExp looks for a leading non-word character to
      // deterine if it's a valid place to search. As such, we need to not
      // include that leading character as part of our match.
      if (re.test(part)) {
        if (/\W/.test(part[0])) {
          return <span>{part[0]}<strong>{part.slice(1)}</strong></span>
        }
        return <strong>{part}</strong>
      }
      return part
    });
    return <span>{parts}</span>;
  };

  _renderFolderIcon = (item)=> {
    return (
      <RetinaImg
        name={`${item.name}.png`}
        fallback={'folder.png'}
        mode={RetinaImg.Mode.ContentIsMask} />
    )
  };

  _renderCheckbox = (item)=> {
    const styles = {}
    let checkStatus;
    styles.backgroundColor = item.backgroundColor

    if (item.usage === 0) {
      checkStatus = <span />
    } else if (item.usage < item.numThreads) {
      checkStatus = (
        <RetinaImg
          className="check-img dash"
          name="tagging-conflicted.png"
          mode={RetinaImg.Mode.ContentPreserve}
          onClick={() => this._onSelectCategory(item)}/>
      )
    } else {
      checkStatus = (
        <RetinaImg
          className="check-img check"
          name="tagging-checkmark.png"
          mode={RetinaImg.Mode.ContentPreserve}
          onClick={() => this._onSelectCategory(item)}/>
      )
    }

    return (
      <div className="check-wrap" style={styles}>
        <RetinaImg
          className="check-img check"
          name="tagging-checkbox.png"
          mode={RetinaImg.Mode.ContentPreserve}
          onClick={() => this._onSelectCategory(item)}/>
        {checkStatus}
      </div>
    )
  };

  _renderCreateNewItem = ({searchValue})=> {
    const {account} = this.props
    let picName = ''
    if (account) {
      picName = account.usesLabels() ? 'tag' : 'folder'
    }

    return (
      <div className="category-item category-create-new">
        <RetinaImg
          name={`${picName}.png`}
          className={`category-create-new-${picName}`}
          mode={RetinaImg.Mode.ContentIsMask} />
        <div className="category-display-name">
          <strong>&ldquo;{searchValue}&rdquo;</strong> (create new)
        </div>
      </div>
    )
  };

  _renderItem = (item)=> {
    if (item.divider) {
      return <Menu.Item key={item.id} divider={item.divider} />
    } else if (item.newCategoryItem) {
      return this._renderCreateNewItem(item)
    }

    const {account} = this.props
    let icon;

    if (account) {
      icon = account.usesLabels() ? this._renderCheckbox(item) : this._renderFolderIcon(item);
    } else {
      return <span />
    }

    return (
      <div className="category-item">
        {icon}
        <div className="category-display-name">
          {this._renderBoldedSearchResults(item)}
        </div>
      </div>
    )
  };

  render() {
    const {account} = this.props
    let placeholder = ''
    if (account) {
      placeholder = account.usesLabels() ? 'Label as' : 'Move to folder'
    }

    const headerComponents = [
      <input
        type="text"
        tabIndex="1"
        key="textfield"
        className="search"
        placeholder={placeholder}
        value={this.state.searchValue}
        onChange={this._onSearchValueChange} />,
    ]

    return (
      <div className="category-picker-popover">
        <Menu
          ref="menu"
          headerComponents={headerComponents}
          footerComponents={[]}
          items={this.state.categoryData}
          itemKey={item => item.id}
          itemContent={this._renderItem}
          onSelect={this._onSelectCategory}
          defaultSelectedIndex={this.state.searchValue === "" ? -1 : 0}
        />
      </div>
    )
  }
}
