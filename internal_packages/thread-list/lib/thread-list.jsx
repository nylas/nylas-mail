import _ from 'underscore';
import React from 'react';
import ReactDOM from 'react-dom';
import classnames from 'classnames';

import {
  MultiselectList,
  FocusContainer,
  EmptyListState,
  FluxContainer } from 'nylas-component-kit';

import {
  Actions,
  CanvasUtils,
  TaskFactory,
  ChangeUnreadTask,
  ChangeStarredTask,
  CategoryStore,
  ExtensionRegistry,
  FocusedContentStore,
  FocusedPerspectiveStore } from 'nylas-exports';

import ThreadListColumns from './thread-list-columns';
import ThreadListScrollTooltip from './thread-list-scroll-tooltip';
import ThreadListStore from './thread-list-store';
import ThreadListContextMenu from './thread-list-context-menu';
import CategoryRemovalTargetRulesets from './category-removal-target-rulesets';


class ThreadList extends React.Component {
  static displayName = 'ThreadList';
  static containerRequired = false;
  static containerStyles = {
    minWidth: 300,
    maxWidth: 3000,
  };

  constructor(props) {
    super(props);
    this._onShowContextMenu = this._onShowContextMenu.bind(this);
    this._onDragStart = this._onDragStart.bind(this);
    this._onDragEnd = this._onDragEnd.bind(this);
    this._onResize = this._onResize.bind(this);
    this._onStarItem = this._onStarItem.bind(this);
    this._onSnoozeItem = this._onSnoozeItem.bind(this);
    this._onRemoveFromView = this._onRemoveFromView.bind(this);
    this._onArchiveItem = this._onArchiveItem.bind(this);
    this._onDeleteItem = this._onDeleteItem.bind(this);
    this._onSelectRead = this._onSelectRead.bind(this);
    this._onSelectUnread = this._onSelectUnread.bind(this);
    this._onSelectStarred = this._onSelectStarred.bind(this);
    this._onSelectUnstarred = this._onSelectUnstarred.bind(this);
    this.state =
      {style: 'unknown'};
  }

  componentDidMount() {
    window.addEventListener('resize', this._onResize, true);
    ReactDOM.findDOMNode(this).addEventListener('contextmenu', this._onShowContextMenu);
    return this._onResize();
  }

  componentWillUnmount() {
    window.removeEventListener('resize', this._onResize, true);
    return ReactDOM.findDOMNode(this).removeEventListener('contextmenu', this._onShowContextMenu);
  }

  _shift({offset, afterRunning}) {
    const dataSource = ThreadListStore.dataSource();
    const focusedId = FocusedContentStore.focusedId('thread');
    const focusedIdx = Math.min(dataSource.count() - 1, Math.max(0, dataSource.indexOfId(focusedId) + offset));
    const item = dataSource.get(focusedIdx);
    afterRunning();
    Actions.setFocus({collection: 'thread', item});
  }

  _keymapHandlers() {
    return {
      'core:remove-from-view': () => {
        return this._onRemoveFromView();
      },
      'core:gmail-remove-from-view': () => {
        return this._onRemoveFromView(CategoryRemovalTargetRulesets.Gmail);
      },
      'core:archive-item': this._onArchiveItem,
      'core:delete-item': this._onDeleteItem,
      'core:star-item': this._onStarItem,
      'core:snooze-item': this._onSnoozeItem,
      'core:mark-important': () => this._onSetImportant(true),
      'core:mark-unimportant': () => this._onSetImportant(false),
      'core:mark-as-unread': () => this._onSetUnread(true),
      'core:mark-as-read': () => this._onSetUnread(false),
      'core:report-as-spam': () => this._onMarkAsSpam(false),
      'core:remove-and-previous': () => {
        return this._shift({offset: -1, afterRunning: this._onRemoveFromView});
      },
      'core:remove-and-next': () => {
        return this._shift({offset: 1, afterRunning: this._onRemoveFromView});
      },
      'thread-list:select-read': this._onSelectRead,
      'thread-list:select-unread': this._onSelectUnread,
      'thread-list:select-starred': this._onSelectStarred,
      'thread-list:select-unstarred': this._onSelectUnstarred,
    };
  }

  _threadPropsProvider(item) {
    let classes = classnames({
      unread: item.unread,
    });
    classes += ExtensionRegistry.ThreadList.extensions()
    .filter(ext => (ext.cssClassNamesForThreadListItem != null))
    .reduce(((prev, ext) => `${prev} ${ext.cssClassNamesForThreadListItem(item)}`), ' ');

    const props =
      {className: classes};

    props.shouldEnableSwipe = () => {
      const perspective = FocusedPerspectiveStore.current();
      const tasks = perspective.tasksForRemovingItems([item], CategoryRemovalTargetRulesets.Default);
      return tasks.length > 0;
    };

    props.onSwipeRightClass = () => {
      const perspective = FocusedPerspectiveStore.current();
      const tasks = perspective.tasksForRemovingItems([item], CategoryRemovalTargetRulesets.Default);
      if (tasks.length === 0) { return null; }

      // TODO this logic is brittle
      const task = tasks[0];
      let name;
      if (task instanceof ChangeStarredTask) {
        name = 'unstar'
      } else {
        name = task.categoriesToAdd().length === 1 ?
          task.categoriesToAdd()[0].name : 'remove';
      }
      return `swipe-${name}`;
    };

    props.onSwipeRight = (callback) => {
      const perspective = FocusedPerspectiveStore.current();
      const tasks = perspective.tasksForRemovingItems([item], CategoryRemovalTargetRulesets.Default);
      if (tasks.length === 0) { callback(false); }
      Actions.closePopover();
      Actions.queueTasks(tasks);
      return callback(true);
    };

    if (FocusedPerspectiveStore.current().isInbox()) {
      props.onSwipeLeftClass = 'swipe-snooze';
      props.onSwipeCenter = () => {
        Actions.closePopover();
      };
      props.onSwipeLeft = callback => {
        // TODO this should be grabbed from elsewhere
        const SnoozePopover = require('../../thread-snooze/lib/snooze-popover').default; // eslint-disable-line global-require

        const element = document.querySelector(`[data-item-id="${item.id}"]`);
        const originRect = element.getBoundingClientRect();
        Actions.openPopover(
          <SnoozePopover
            threads={[item]}
            swipeCallback={callback}
          />,
          {originRect, direction: 'right', fallbackDirection: 'down'}
        );
      };
    }

    return props;
  }

  _targetItemsForMouseEvent(event) {
    const itemThreadId = this.refs.list.itemIdAtPoint(event.clientX, event.clientY);
    if (!itemThreadId) {
      return null;
    }

    const dataSource = ThreadListStore.dataSource();
    if (dataSource.selection.ids().includes(itemThreadId)) {
      return {
        threadIds: dataSource.selection.ids(),
        accountIds: _.uniq(_.pluck(dataSource.selection.items(), 'accountId')),
      };
    }
    const thread = dataSource.getById(itemThreadId);
    if (!thread) { return null; }
    return {
      threadIds: [thread.id],
      accountIds: [thread.accountId],
    };
  }

  _onShowContextMenu(event) {
    const data = this._targetItemsForMouseEvent(event);
    if (!data) {
      event.preventDefault();
    } else {
      (new ThreadListContextMenu(data)).displayMenu();
    }
  }

  _onDragStart(event) {
    const data = this._targetItemsForMouseEvent(event);
    if (!data) {
      event.preventDefault();
      return;
    }

    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.dragEffect = "move";

    const canvas = CanvasUtils.canvasWithThreadDragImage(data.threadIds.length);
    event.dataTransfer.setDragImage(canvas, 10, 10);
    event.dataTransfer.setData("nylas-threads-data", JSON.stringify(data));
    event.dataTransfer.setData(`nylas-accounts=${data.accountIds.join(',')}`, "1");
  }

  _onDragEnd() {}

  _onResize() {
    const current = this.state.style;
    const desired = ReactDOM.findDOMNode(this).offsetWidth < 540 ? 'narrow' : 'wide';
    if (current !== desired) {
      this.setState({style: desired});
    }
  }

  _threadsForKeyboardAction() {
    if (!ThreadListStore.dataSource()) { return null; }
    const focused = FocusedContentStore.focused('thread');
    if (focused) {
      return [focused];
    } else if (ThreadListStore.dataSource().selection.count() > 0) {
      return ThreadListStore.dataSource().selection.items();
    }
    return null;
  }

  _onStarItem() {
    const threads = this._threadsForKeyboardAction();
    if (!threads) { return; }
    const task = TaskFactory.taskForInvertingStarred({threads});
    Actions.queueTask(task);
  }

  _onSnoozeItem() {
    const threads = this._threadsForKeyboardAction();
    if (!threads) { return; }
    // TODO this should be grabbed from elsewhere
    const SnoozePopover = require('../../thread-snooze/lib/snooze-popover').default; // eslint-disable-line global-require

    const element = document.querySelector(".snooze-button.btn.btn-toolbar");
    if (!element) { return; }
    const originRect = element.getBoundingClientRect();
    Actions.openPopover(
      <SnoozePopover threads={threads} />,
      {originRect, direction: 'down'}
    )
  }

  _onSetImportant(important) {
    const threads = this._threadsForKeyboardAction();
    if (!threads) { return; }
    if (!NylasEnv.config.get('core.workspace.showImportant')) { return; }

    let tasks;
    if (important) {
      tasks = TaskFactory.tasksForApplyingCategories({
        threads,
        categoriesToRemove() { return []; },
        categoriesToAdd(accountId) {
          return [CategoryStore.getStandardCategory(accountId, 'important')];
        }});
    } else {
      tasks = TaskFactory.tasksForApplyingCategories({
        threads,
        categoriesToRemove(accountId) {
          const category = CategoryStore.getStandardCategory(accountId, 'important');
          if (category) { return [category]; }
          return [];
        }});
    }

    Actions.queueTasks(tasks);
  }

  _onSetUnread(unread) {
    const threads = this._threadsForKeyboardAction();
    if (!threads) { return; }
    Actions.queueTask(new ChangeUnreadTask({threads, unread}));
    Actions.popSheet();
  }

  _onMarkAsSpam() {
    const threads = this._threadsForKeyboardAction();
    if (!threads) { return; }
    const tasks = TaskFactory.tasksForMarkingAsSpam({
      threads});
    Actions.queueTasks(tasks);
  }

  _onRemoveFromView(ruleset = CategoryRemovalTargetRulesets.Default) {
    const threads = this._threadsForKeyboardAction();
    if (!threads) { return; }
    const current = FocusedPerspectiveStore.current();
    const tasks = current.tasksForRemovingItems(threads, ruleset);
    Actions.queueTasks(tasks);
    Actions.popSheet();
  }

  _onArchiveItem() {
    const threads = this._threadsForKeyboardAction();
    if (threads) {
      const tasks = TaskFactory.tasksForArchiving({
        threads});
      Actions.queueTasks(tasks);
    }
    Actions.popSheet();
  }

  _onDeleteItem() {
    const threads = this._threadsForKeyboardAction();
    if (threads) {
      const tasks = TaskFactory.tasksForMovingToTrash({
        threads});
      Actions.queueTasks(tasks);
    }
    Actions.popSheet();
  }

  _onSelectRead() {
    const dataSource = ThreadListStore.dataSource();
    const items = dataSource.itemsCurrentlyInViewMatching(item => !item.unread);
    return this.refs.list.handler().onSelect(items);
  }

  _onSelectUnread() {
    const dataSource = ThreadListStore.dataSource();
    const items = dataSource.itemsCurrentlyInViewMatching(item => item.unread);
    return this.refs.list.handler().onSelect(items);
  }

  _onSelectStarred() {
    const dataSource = ThreadListStore.dataSource();
    const items = dataSource.itemsCurrentlyInViewMatching(item => item.starred);
    return this.refs.list.handler().onSelect(items);
  }

  _onSelectUnstarred() {
    const dataSource = ThreadListStore.dataSource();
    const items = dataSource.itemsCurrentlyInViewMatching(item => !item.starred);
    return this.refs.list.handler().onSelect(items);
  }

  render() {
    let itemHeight;
    let columns;
    if (this.state.style === 'wide') {
      itemHeight = 36;
      columns = ThreadListColumns.Wide;
    } else {
      itemHeight = 85;
      columns = ThreadListColumns.Narrow;
    }
    return (
      <FluxContainer
        stores={[ThreadListStore]}
        getStateFromStores={() => ({dataSource: ThreadListStore.dataSource()})}
      >
        <FocusContainer collection="thread">
          <MultiselectList
            ref="list"
            columns={columns}
            itemPropsProvider={this._threadPropsProvider}
            itemHeight={itemHeight}
            className={`thread-list thread-list-${this.state.style}`}
            scrollTooltipComponent={ThreadListScrollTooltip}
            emptyComponent={EmptyListState}
            keymapHandlers={this._keymapHandlers()}
            onDoubleClick={(thread) => Actions.popoutThread(thread)}
            onDragStart={this._onDragStart}
            onDragEnd={this._onDragEnd}
            draggable="true"
          />
        </FocusContainer>
      </FluxContainer>
    );
  }
}

export default ThreadList;
