/* eslint jsx-a11y/tabindex-no-positive: 0 */
import React, { Component } from 'react';
import PropTypes from 'prop-types';
import { Menu, RetinaImg, LabelColorizer, BoldedSearchResult } from 'nylas-component-kit';
import {
  Utils,
  Actions,
  TaskQueue,
  CategoryStore,
  Folder,
  SyncbackCategoryTask,
  ChangeFolderTask,
  ChangeLabelsTask,
  FocusedPerspectiveStore,
} from 'mailspring-exports';
import { Categories } from 'nylas-observables';

export default class MovePickerPopover extends Component {
  static propTypes = {
    threads: PropTypes.array.isRequired,
    account: PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props);
    this._standardFolders = [];
    this._userCategories = [];
    this.state = this._recalculateState(this.props, { searchValue: '' });
  }

  componentDidMount() {
    this._registerObservables();
  }

  componentWillReceiveProps(nextProps) {
    this._registerObservables(nextProps);
    this.setState(this._recalculateState(nextProps));
  }

  componentWillUnmount() {
    this._unregisterObservables();
  }

  _registerObservables = (props = this.props) => {
    this._unregisterObservables();
    this.disposables = [
      Categories.forAccount(props.account)
        .sort()
        .subscribe(this._onCategoriesChanged),
    ];
  };

  _unregisterObservables = () => {
    if (this.disposables) {
      this.disposables.forEach(disp => disp.dispose());
    }
  };

  _recalculateState = (props = this.props, { searchValue = this.state.searchValue || '' } = {}) => {
    const { threads, account } = props;
    if (threads.length === 0) {
      return { categoryData: [], searchValue };
    }

    const currentCategories = FocusedPerspectiveStore.current().categories() || [];
    const currentCategoryIds = currentCategories.map(c => c.id);
    const viewingAllMail = !currentCategories.find(c => c.role === 'spam' || c.role === 'trash');
    const hidden = account ? ['drafts', 'sent', 'snoozed'] : [];

    if (viewingAllMail) {
      hidden.push('all');
    }

    const categoryData = []
      .concat(this._standardFolders)
      .concat([{ divider: true, id: 'category-divider' }])
      .concat(this._userCategories)
      .filter(
        cat =>
          // remove categories that are part of the current perspective or locked
          !hidden.includes(cat.role) && !currentCategoryIds.includes(cat.id)
      )
      .filter(cat => Utils.wordSearchRegExp(searchValue).test(cat.displayName))
      .map(cat => {
        if (cat.divider) {
          return cat;
        }
        return {
          id: cat.id,
          category: cat,
          displayName: cat.displayName,
          backgroundColor: LabelColorizer.backgroundColorDark(cat),
        };
      });

    if (searchValue.length > 0) {
      const newItemData = {
        searchValue: searchValue,
        newCategoryItem: true,
        id: 'category-create-new',
      };
      categoryData.push(newItemData);
    }
    return { categoryData, searchValue };
  };

  _onCategoriesChanged = categories => {
    this._standardFolders = categories.filter(c => c.role && c instanceof Folder);
    this._userCategories = categories.filter(c => !c.role || !(c instanceof Folder));
    this.setState(this._recalculateState());
  };

  _onEscape = () => {
    Actions.closePopover();
  };

  _onSelectCategory = item => {
    if (this.props.threads.length === 0) {
      return;
    }

    if (item.newCategoryItem) {
      this._onCreateCategory(item);
    } else {
      this._onMoveToCategory(item);
    }
    Actions.popSheet();
    Actions.closePopover();
  };

  _onCreateCategory = () => {
    const syncbackTask = new SyncbackCategoryTask({
      path: this.state.searchValue,
      accountId: this.props.account.id,
    });

    TaskQueue.waitForPerformRemote(syncbackTask).then(finishedTask => {
      if (!finishedTask.created) {
        AppEnv.showErrorDialog({ title: 'Error', message: `Could not create folder.` });
        return;
      }
      this._onMoveToCategory({ category: finishedTask.created });
    });
    Actions.queueTask(syncbackTask);
  };

  _onMoveToCategory = ({ category }) => {
    const { threads } = this.props;

    if (category instanceof Folder) {
      Actions.queueTask(
        new ChangeFolderTask({
          source: 'Category Picker: New Category',
          threads: threads,
          folder: category,
        })
      );
    } else {
      const all = [];
      threads.forEach(({ labels }) => all.push(...labels));

      Actions.queueTask(
        new ChangeLabelsTask({
          source: 'Category Picker: New Category',
          labelsToRemove: all,
          labelsToAdd: [category],
          threads: threads,
        })
      );
    }
  };

  _onSearchValueChange = event => {
    this.setState(this._recalculateState(this.props, { searchValue: event.target.value }));
  };

  _renderCreateNewItem = ({ searchValue }) => {
    const icon =
      CategoryStore.getInboxCategory(this.props.account) instanceof Folder ? 'folder' : 'tag';

    return (
      <div className="category-item category-create-new">
        <RetinaImg
          name={`${icon}.png`}
          className={`category-create-new-${icon}`}
          mode={RetinaImg.Mode.ContentIsMask}
        />
        <div className="category-display-name">
          <strong>&ldquo;{searchValue}&rdquo;</strong> (create new)
        </div>
      </div>
    );
  };

  _renderItem = item => {
    if (item.divider) {
      return <Menu.Item key={item.id} divider={item.divider} />;
    } else if (item.newCategoryItem) {
      return this._renderCreateNewItem(item);
    }

    const icon =
      item.category instanceof Folder ? (
        <RetinaImg
          name={`${item.name}.png`}
          fallback={'folder.png'}
          mode={RetinaImg.Mode.ContentIsMask}
        />
      ) : (
        <RetinaImg name={`tag.png`} mode={RetinaImg.Mode.ContentIsMask} />
      );

    return (
      <div className="category-item">
        {icon}
        <div className="category-display-name">
          <BoldedSearchResult value={item.displayName} query={this.state.searchValue || ''} />
        </div>
      </div>
    );
  };

  render() {
    const headerComponents = [
      <input
        type="text"
        tabIndex="1"
        key="textfield"
        className="search"
        placeholder={'Move to...'}
        value={this.state.searchValue}
        onChange={this._onSearchValueChange}
      />,
    ];

    return (
      <div className="category-picker-popover">
        <Menu
          headerComponents={headerComponents}
          footerComponents={[]}
          items={this.state.categoryData}
          itemKey={item => item.id}
          itemContent={this._renderItem}
          onSelect={this._onSelectCategory}
          onEscape={this._onEscape}
          defaultSelectedIndex={this.state.searchValue === '' ? -1 : 0}
        />
      </div>
    );
  }
}
