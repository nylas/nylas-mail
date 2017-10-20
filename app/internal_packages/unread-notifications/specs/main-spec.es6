import {
  Contact,
  Message,
  Thread,
  Folder,
  CategoryStore,
  DatabaseStore,
  AccountStore,
  SoundRegistry,
  NativeNotifications,
} from 'mailspring-exports';

import { Notifier } from '../lib/main';

describe('UnreadNotifications', function UnreadNotifications() {
  beforeEach(() => {
    this.notifier = new Notifier();

    const inbox = new Folder({ id: 'l1', role: 'inbox', path: 'Inbox' });
    const archive = new Folder({ id: 'l2', role: 'archive', path: 'Archive' });

    spyOn(CategoryStore, 'getCategoryByRole').andReturn(inbox);

    const account = AccountStore.accounts()[0];

    this.threadA = new Thread({
      id: 'A',
      accountId: 'a',
      folders: [inbox],
    });
    this.threadB = new Thread({
      id: 'B',
      accountId: 'a',
      folders: [archive],
    });

    this.msg1 = new Message({
      id: '1',
      unread: true,
      date: new Date(),
      accountId: 'a',
      from: [new Contact({ name: 'Ben', email: 'benthis.example.com' })],
      subject: 'Hello World',
      threadId: 'A',
      version: 1,
    });
    this.msgNoSender = new Message({
      id: 'no',
      unread: true,
      date: new Date(),
      from: [],
      accountId: 'a',
      subject: 'Hello World',
      threadId: 'A',
      version: 1,
    });
    this.msg2 = new Message({
      id: '2',
      unread: true,
      date: new Date(),
      accountId: 'a',
      from: [new Contact({ name: 'Mark', email: 'markthis.example.com' })],
      subject: 'Hello World 2',
      threadId: 'A',
      version: 1,
    });
    this.msg3 = new Message({
      id: '3',
      unread: true,
      date: new Date(),
      accountId: 'a',
      from: [new Contact({ name: 'Ben', email: 'benthis.example.com' })],
      subject: 'Hello World 3',
      threadId: 'A',
      version: 1,
    });
    this.msg4 = new Message({
      id: '4',
      unread: true,
      date: new Date(),
      accountId: 'a',
      from: [new Contact({ name: 'Ben', email: 'benthis.example.com' })],
      subject: 'Hello World 4',
      threadId: 'A',
      version: 1,
    });
    this.msg5 = new Message({
      id: '5',
      unread: true,
      date: new Date(),
      accountId: 'a',
      from: [new Contact({ name: 'Ben', email: 'benthis.example.com' })],
      subject: 'Hello World 5',
      threadId: 'A',
      version: 1,
    });
    this.msgUnreadButArchived = new Message({
      id: 'uba',
      unread: true,
      date: new Date(),
      accountId: 'a',
      from: [new Contact({ name: 'Mark', email: 'markthis.example.com' })],
      subject: 'Hello World 2',
      threadId: 'B',
      version: 1,
    });
    this.msgRead = new Message({
      id: 'read',
      unread: false,
      date: new Date(),
      accountId: 'a',
      from: [new Contact({ name: 'Mark', email: 'markthis.example.com' })],
      subject: 'Hello World Read Already',
      threadId: 'A',
      version: 1,
    });
    this.msgOld = new Message({
      id: 'old',
      unread: true,
      date: new Date(2000, 1, 1),
      accountId: 'a',
      from: [new Contact({ name: 'Mark', email: 'markthis.example.com' })],
      subject: 'Hello World Old',
      threadId: 'A',
      version: 1,
    });
    this.msgFromMeSameAccount = new Message({
      id: 'from-me',
      unread: true,
      date: new Date(),
      accountId: account.id,
      from: [account.me()],
      subject: 'A Sent Mail!',
      threadId: 'A',
      version: 1,
    });
    this.msgFromMeDiffAccount = new Message({
      id: 'from-me-diff',
      unread: true,
      date: new Date(),
      accountId: 'other',
      from: [account.me()],
      subject: 'A Sent Mail!',
      threadId: 'A',
      version: 1,
    });
    this.msgHigherVersion = new Message({
      id: 'hv',
      unread: true,
      date: new Date(),
      accountId: 'a',
      from: [new Contact({ name: 'Ben', email: 'benthis.example.com' })],
      subject: 'Hello World',
      threadId: 'A',
      version: 2,
    });

    spyOn(DatabaseStore, 'find').andCallFake((klass, id) => {
      if (id === 'A') {
        return Promise.resolve(this.threadA);
      }
      if (id === 'B') {
        return Promise.resolve(this.threadB);
      }
      return Promise.resolve(null);
    });

    spyOn(DatabaseStore, 'findAll').andCallFake(() => {
      return Promise.resolve([this.threadA, this.threadB]);
    });

    this.notification = jasmine.createSpyObj('notification', ['close']);
    spyOn(NativeNotifications, 'displayNotification').andReturn(this.notification);

    spyOn(Promise, 'props').andCallFake(dict => {
      const dictOut = {};
      for (const key of Object.keys(dict)) {
        const val = dict[key];
        if (val.value !== undefined) {
          dictOut[key] = val.value();
        } else {
          dictOut[key] = val;
        }
      }
      return Promise.resolve(dictOut);
    });
  });

  afterEach(() => {
    this.notifier.unlisten();
  });

  it('should create a Notification if there is one unread message', () => {
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msgRead, this.msg1],
      });
      advanceClock(2000);
      expect(NativeNotifications.displayNotification).toHaveBeenCalled();
      const options = NativeNotifications.displayNotification.mostRecentCall.args[0];
      delete options.onActivate;
      expect(options).toEqual({
        title: 'Ben',
        subtitle: 'Hello World',
        body: undefined,
        canReply: true,
        tag: 'unread-update',
      });
    });
  });

  it('should create multiple Notifications if there is more than one but less than five unread messages', () => {
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msg1, this.msg2, this.msg3],
      });
      // Need to call advance clock twice because we call setTimeout twice
      advanceClock(2000);
      advanceClock(2000);
      expect(NativeNotifications.displayNotification.callCount).toEqual(3);
    });
  });

  it('should create Notifications in the order of messages received', () => {
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msg1, this.msg2],
      });
      advanceClock(2000);
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msg3, this.msg4],
      });
      advanceClock(2000);
      advanceClock(2000);
      expect(NativeNotifications.displayNotification.callCount).toEqual(4);
      const subjects = NativeNotifications.displayNotification.calls.map(call => {
        return call.args[0].subtitle;
      });
      const expected = [this.msg1, this.msg2, this.msg3, this.msg4].map(msg => msg.subject);
      expect(subjects).toEqual(expected);
    });
  });

  it('should create a Notification if there are five or more unread messages', () => {
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msg1, this.msg2, this.msg3, this.msg4, this.msg5],
      });
      advanceClock(2000);
      expect(NativeNotifications.displayNotification).toHaveBeenCalled();
      const [{ title, tag }] = NativeNotifications.displayNotification.mostRecentCall.args;
      expect({ title, tag }).toEqual({
        title: '5 Unread Messages',
        tag: 'unread-update',
      });
    });
  });

  it('should create a Notification correctly, even if new mail has no sender', () => {
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msgNoSender],
      });
      expect(NativeNotifications.displayNotification).toHaveBeenCalled();

      const options = NativeNotifications.displayNotification.mostRecentCall.args[0];
      delete options.onActivate;
      expect(options).toEqual({
        title: 'Unknown',
        subtitle: 'Hello World',
        body: undefined,
        canReply: true,
        tag: 'unread-update',
      });
    });
  });

  it('should not create a Notification if there are no new messages', () => {
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [],
      });
      expect(NativeNotifications.displayNotification).not.toHaveBeenCalled();
      await this.notifier._onDatabaseChanged({});
      expect(NativeNotifications.displayNotification).not.toHaveBeenCalled();
    });
  });

  it('should not notify about unread messages that are outside the inbox', () => {
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msgUnreadButArchived, this.msg1],
      });
      expect(NativeNotifications.displayNotification).toHaveBeenCalled();
      const options = NativeNotifications.displayNotification.mostRecentCall.args[0];
      delete options.onActivate;
      expect(options).toEqual({
        title: 'Ben',
        subtitle: 'Hello World',
        body: undefined,
        canReply: true,
        tag: 'unread-update',
      });
    });
  });

  it('should not create a Notification if the new messages are read', () => {
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msgRead],
      });
      expect(NativeNotifications.displayNotification).not.toHaveBeenCalled();
    });
  });
  it('should not create a Notification if the message model is being updated', () => {
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msgHigherVersion],
      });
      expect(NativeNotifications.displayNotification).not.toHaveBeenCalled();
    });
  });

  it('should not create a Notification if the new messages are actually old ones', () => {
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msgOld],
      });
      expect(NativeNotifications.displayNotification).not.toHaveBeenCalled();
    });
  });

  it('should not create a Notification if the new message is one I sent from the same account', () => {
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msgFromMeSameAccount],
      });
      expect(NativeNotifications.displayNotification).not.toHaveBeenCalled();
    });
  });

  it('should xcreate a Notification if the new message is one I sent from a different linked account', () => {
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msgFromMeDiffAccount],
      });
      expect(NativeNotifications.displayNotification).toHaveBeenCalled();
    });
  });

  it('clears notifications when a thread is read', () => {
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msg1],
      });
      expect(NativeNotifications.displayNotification).toHaveBeenCalled();
      expect(this.notification.close).not.toHaveBeenCalled();

      const read = this.threadA.clone();
      read.unread = false;
      await this.notifier._onDatabaseChanged({
        objectClass: Thread.name,
        objects: [read],
      });
      expect(this.notification.close).toHaveBeenCalled();
    });
  });

  it('should play a sound when it gets new mail', () => {
    spyOn(AppEnv.config, 'get').andCallFake(config => {
      if (config === 'core.notifications.enabled') return true;
      if (config === 'core.notifications.sounds') return true;
      return undefined;
    });

    spyOn(SoundRegistry, 'playSound');
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msg1],
      });
      expect(AppEnv.config.get.calls[1].args[0]).toBe('core.notifications.sounds');
      expect(SoundRegistry.playSound).toHaveBeenCalledWith('new-mail');
    });
  });

  it('should not play a sound if the config is off', () => {
    spyOn(AppEnv.config, 'get').andCallFake(config => {
      if (config === 'core.notifications.enabled') return true;
      if (config === 'core.notifications.sounds') return false;
      return undefined;
    });
    spyOn(SoundRegistry, 'playSound');
    waitsForPromise(async () => {
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msg1],
      });
      expect(AppEnv.config.get.calls[1].args[0]).toBe('core.notifications.sounds');
      expect(SoundRegistry.playSound).not.toHaveBeenCalled();
    });
  });

  it('should not play a sound if other notiications are still in flight', () => {
    spyOn(AppEnv.config, 'get').andCallFake(config => {
      if (config === 'core.notifications.enabled') return true;
      if (config === 'core.notifications.sounds') return true;
      return undefined;
    });
    waitsForPromise(async () => {
      spyOn(SoundRegistry, 'playSound');
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msg1, this.msg2],
      });
      expect(SoundRegistry.playSound).toHaveBeenCalled();
      SoundRegistry.playSound.reset();
      await this.notifier._onDatabaseChanged({
        objectClass: Message.name,
        objects: [this.msg3],
      });
      expect(SoundRegistry.playSound).not.toHaveBeenCalled();
    });
  });
});
