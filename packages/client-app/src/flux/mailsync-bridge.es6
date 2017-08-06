import DatabaseStore from './stores/database-store';
import DatabaseChangeRecord from './stores/database-change-record';
import DatabaseObjectRegistry from '../registries/database-object-registry';
import MailsyncProcess from '../mailsync-process';
import Actions from './actions';
import Utils from './models/utils';

let AccountStore = null;
let IdentityStore = null;
let Task = null;

export default class MailsyncBridge {
  constructor() {
    if (!NylasEnv.isMainWindow()) {
      // maybe bind as listener?
      return;
    }

    Actions.queueTask.listen(this.onQueueTask, this);
    Actions.queueTasks.listen(this.onQueueTasks, this);
    Actions.cancelTask.listen(this.onCancelTask, this);
    Actions.fetchBodies.listen(this.onFetchBodies, this);

    this.clients = {};

    Task = require('./tasks/task').default; //eslint-disable-line

    IdentityStore = require('./stores/identity-store').default;
    IdentityStore.listen(() => {
      Object.values(this.clients).each(c => c.kill());
      this.ensureClients();
    }, this);

    AccountStore = require('./stores/account-store').default; //eslint-disable-line
    AccountStore.listen(this.ensureClients, this);

    this.ensureClients();

    NylasEnv.onBeforeUnload(this.onBeforeUnload);
  }

  ensureClients() {
    const toLaunch = [];
    const clientsToStop = Object.assign({}, this.clients);
    const identity = IdentityStore.identity();

    for (const acct of AccountStore.accounts()) {
      if (!this.clients[acct.id]) {
        toLaunch.push(acct);
      } else {
        delete clientsToStop[acct.id];
      }
    }

    for (const client of Object.values(clientsToStop)) {
      client.kill();
    }

    toLaunch.forEach((acct) => {
      const client = new MailsyncProcess(NylasEnv.getLoadSettings(), identity, acct);
      client.sync();
      client.on('deltas', this.onIncomingMessages);
      client.on('close', () => {
        delete this.clients[acct.id];
      });
      this.clients[acct.id] = client;
    });
  }

  onQueueTask(task) {
    if (!DatabaseObjectRegistry.isInRegistry(task.constructor.name)) {
      console.log(task);
      throw new Error("You must queue a `Task` instance which is registred with the DatabaseObjectRegistry")
    }
    if (!task.id) {
      console.log(task);
      throw new Error("Tasks must have an ID prior to being queued. Check that your Task constructor is calling `super`");
    }
    if (!task.accountId) {
      throw new Error("Tasks must have an accountId.");
    }

    task.validate();
    task.status = 'local';
    this.sendMessageToAccount(task.accountId, {type: 'queue-task', task: task});
  }

  onQueueTasks(tasks) {
    if (!tasks || !tasks.length) { return; }
    for (const task of tasks) { this.onQueueTask(task); }
  }

  onCancelTask(taskOrId) {
    const task = this._resolveTaskArgument(taskOrId);
    if (!task) {
      throw new Error("Couldn't find task in queue to cancel");
    }
    this.sendMessageToAccount(task.accountId, {type: 'cancel-task', taskId: task.id});
  }

  onIncomingMessages(msgs) {
    // todo bg
    // dispatch the messages to other windows?

    for (const msg of msgs) {
      if (msg.length === 0) {
        continue;
      }
      if (msg[0] !== '{') {
        console.log(`Sync worker sent non-JSON formatted message: ${msg}`)
        continue;
      }

      const {type, objects, objectClass} = JSON.parse(msg);
      const models = objects.map(Utils.convertToModel);
      DatabaseStore.trigger(new DatabaseChangeRecord({type, objectClass, objects: models}));

      if (objects[0] instanceof Task) {
        for (const task of objects) {
          if (task.status === 'complete') {
            if (task.error != null) {
              task.onError(task.error);
            } else {
              task.onSuccess();
            }
          }
        }
      }
    }
  }

  onFetchBodies(messages) {
    const byAccountId = {};
    for (const msg of messages) {
      byAccountId[msg.accountId] = byAccountId[msg.accountId] || [];
      byAccountId[msg.accountId].push(msg.id);
    }
    for (const accountId of Object.keys(byAccountId)) {
      this.sendMessageToAccount(accountId, {type: 'need-bodies', ids: byAccountId[accountId]});
    }
  }

  onBeforeUnload = () => {
    for (const client of Object.values(this.clients)) {
      client.kill();
    }
    this.clients = [];
    return true;
  }

  sendMessageToAccount(accountId, json) {
    if (!this.clients[accountId]) {
      throw new Error(`No mailsync worker is running for account id ${accountId}.`);
    }
    this.clients[accountId].sendMessage(json);
  }
}
