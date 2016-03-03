/** @babel */
import moment from 'moment';
import _ from 'underscore';
import {
  Actions,
  Thread,
  Category,
  CategoryStore,
  DatabaseStore,
  AccountStore,
  SyncbackCategoryTask,
  TaskQueueStatusStore,
  TaskFactory,
  DateUtils,
} from 'nylas-exports';
import {SNOOZE_CATEGORY_NAME, DATE_FORMAT_SHORT} from './snooze-constants'


const SnoozeUtils = {

  snoozedUntilMessage(snoozeDate, now = moment()) {
    let message = 'Snoozed'
    if (snoozeDate) {
      let dateFormat = DATE_FORMAT_SHORT
      const date = moment(snoozeDate)
      const hourDifference = moment.duration(date.diff(now)).asHours()

      if (hourDifference < 24) {
        dateFormat = dateFormat.replace('MMM D, ', '');
      }
      if (date.minutes() === 0) {
        dateFormat = dateFormat.replace(':mm', '');
      }

      message += ` until ${DateUtils.format(date, dateFormat)}`;
    }
    return message;
  },

  createSnoozeCategory(accountId, name = SNOOZE_CATEGORY_NAME) {
    const category = new Category({
      displayName: name,
      accountId: accountId,
    })
    const task = new SyncbackCategoryTask({category})

    Actions.queueTask(task)
    return TaskQueueStatusStore.waitForPerformRemote(task).then(()=>{
      return DatabaseStore.findBy(Category, {clientId: category.clientId})
      .then((updatedCat)=> {
        if (updatedCat && updatedCat.isSavedRemotely()) {
          return Promise.resolve(updatedCat)
        }
        return Promise.reject(new Error('Could not create Snooze category'))
      })
    })
  },

  whenCategoriesReady() {
    const categoriesReady = ()=> CategoryStore.categories().length > 0
    if (!categoriesReady()) {
      return new Promise((resolve)=> {
        const unsubscribe = CategoryStore.listen(()=> {
          if (categoriesReady()) {
            unsubscribe()
            resolve()
          }
        })
      })
    }
    return Promise.resolve()
  },

  getSnoozeCategory(accountId, categoryName = SNOOZE_CATEGORY_NAME) {
    return SnoozeUtils.whenCategoriesReady()
    .then(()=> {
      const allCategories = CategoryStore.categories(accountId)
      const category = _.findWhere(allCategories, {displayName: categoryName})
      if (category) {
        return Promise.resolve(category);
      }
      return SnoozeUtils.createSnoozeCategory(accountId, categoryName)
    })
  },

  getSnoozeCategoriesByAccount(accounts = AccountStore.accounts()) {
    const snoozeCategoriesByAccountId = {}
    accounts.forEach(({id})=> {
      if (snoozeCategoriesByAccountId[id] != null) return;
      snoozeCategoriesByAccountId[id] = SnoozeUtils.getSnoozeCategory(id)
    })
    return Promise.props(snoozeCategoriesByAccountId)
  },

  moveThreads(threads, {snooze, getSnoozeCategory, getInboxCategory, description} = {}) {
    const tasks = TaskFactory.tasksForApplyingCategories({
      threads,
      categoriesToRemove: snooze ? getInboxCategory : getSnoozeCategory,
      categoryToAdd: snooze ? getSnoozeCategory : getInboxCategory,
      taskDescription: description,
    })

    Actions.queueTasks(tasks)
    const promises = tasks.map(task => TaskQueueStatusStore.waitForPerformRemote(task))
    // Resolve with the updated threads
    return (
      Promise.all(promises).then(()=> {
        return DatabaseStore.modelify(Thread, _.pluck(threads, 'clientId'))
      })
    )
  },

  moveThreadsToSnooze(threads, snoozeCategoriesByAccountPromise, snoozeDate) {
    return snoozeCategoriesByAccountPromise
    .then((snoozeCategoriesByAccountId)=> {
      const getSnoozeCategory = (accId)=> snoozeCategoriesByAccountId[accId]
      const {getInboxCategory} = CategoryStore
      const description = SnoozeUtils.snoozedUntilMessage(snoozeDate)
      return SnoozeUtils.moveThreads(
        threads,
        {snooze: true, getSnoozeCategory, getInboxCategory, description}
      )
    })
  },

  moveThreadsFromSnooze(threads, snoozeCategoriesByAccountPromise) {
    return snoozeCategoriesByAccountPromise
    .then((snoozeCategoriesByAccountId)=> {
      const getSnoozeCategory = (accId)=> snoozeCategoriesByAccountId[accId]
      const {getInboxCategory} = CategoryStore
      const description = 'Unsnoozed';
      return SnoozeUtils.moveThreads(
        threads,
        {snooze: false, getSnoozeCategory, getInboxCategory, description}
      )
    })
  },
}

export default SnoozeUtils
