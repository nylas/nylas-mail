import _ from 'underscore'
import {
  Thread,
  Actions,
  Message,
  TaskFactory,
  DatabaseStore,
  FocusedPerspectiveStore} from 'nylas-exports'

export default class ThreadListContextMenu {
  constructor({threadIds = [], accountIds = []}) {
    this.threadIds = threadIds
    this.accountIds = accountIds
  }

  menuItemTemplate() {
    return DatabaseStore.modelify(Thread, this.threadIds)
    .then((threads) => {
      this.threads = threads;

      return Promise.all([
        this.replyItem(),
        this.replyAllItem(),
        this.forwardItem(),
        {type: 'separator'},
        this.archiveItem(),
        this.trashItem(),
        this.markAsReadItem(),
        this.starItem(),
        // this.moveToOrLabelItem(),
        // {type: 'separator'},
        // this.extensionItems(),
      ])
    }).then((menuItems) => {
      return _.filter(_.compact(menuItems), (item, index) => {
        if ((index === 0 || index === menuItems.length - 1) && item.type === "separator") {
          return false
        }
        return true
      });
    });
  }

  replyItem() {
    if (this.threadIds.length !== 1) { return null }
    return {
      label: "Reply",
      click: () => {
        Actions.composeReply({threadId: this.threadIds[0], popout: true});
      },
    }
  }

  replyAllItem() {
    if (this.threadIds.length !== 1) { return null }
    DatabaseStore.findBy(Message, {threadId: this.threadIds[0]})
    .order(Message.attributes.date.descending())
    .limit(1)
    .then((message) => {
      if (message && message.canReplyAll()) {
        return {
          label: "Reply All",
          click: () => {
            Actions.composeReplyAll({threadId: this.threadIds[0], popout: true});
          },
        }
      }
      return null
    })
  }

  forwardItem() {
    if (this.threadIds.length !== 1) { return null }
    return {
      label: "Forward",
      click: () => {
        Actions.composeForward({threadId: this.threadIds[0], popout: true});
      },
    }
  }

  archiveItem() {
    if (!FocusedPerspectiveStore.current().canArchiveThreads()) {
      return null
    }
    return {
      label: "Archive",
      click: () => {
        const tasks = TaskFactory.tasksForArchiving({
          threads: this.threads,
          fromPerspective: FocusedPerspectiveStore.current(),
        })
        Actions.queueTasks(tasks)
      },
    }
  }

  trashItem() {
    if (!FocusedPerspectiveStore.current().canTrashThreads()) {
      return null
    }
    return {
      label: "Trash",
      click: () => {
        const tasks = TaskFactory.tasksForMovingToTrash({
          threads: this.threads,
          fromPerspective: FocusedPerspectiveStore.current(),
        })
        Actions.queueTasks(tasks)
      },
    }
  }

  markAsReadItem() {
    const unread = _.every(this.threads, (t) => {
      return _.isMatch(t, {unread: false})
    });
    const dir = unread ? "Unread" : "Read"

    return {
      label: `Mark as ${dir}`,
      click: () => {
        const task = TaskFactory.taskForInvertingUnread({
          threads: this.threads,
        })
        Actions.queueTask(task)
      },
    }
  }

  starItem() {
    const starred = _.every(this.threads, (t) => {
      return _.isMatch(t, {starred: false})
    });

    let dir = ""
    let star = "Star"
    if (!starred) {
      dir = "Remove "
      star = (this.threadIds.length > 1) ? "Stars" : "Star"
    }


    return {
      label: `${dir}${star}`,
      click: () => {
        const task = TaskFactory.taskForInvertingStarred({
          threads: this.threads,
        })
        Actions.queueTask(task)
      },
    }
  }

  displayMenu() {
    const {remote} = require('electron')
    this.menuItemTemplate().then((template) => {
      remote.Menu.buildFromTemplate(template)
        .popup(remote.getCurrentWindow());
    });
  }
}
