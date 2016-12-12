import Contact from '../../../src/flux/models/contact'
import Message from '../../../src/flux/models/message'
import Thread from '../../../src/flux/models/thread'
import Category from '../../../src/flux/models/category'
import CategoryStore from '../../../src/flux/stores/category-store'
import DatabaseStore from '../../../src/flux/stores/database-store'
import AccountStore from '../../../src/flux/stores/account-store'
import SoundRegistry from '../../../src/registries/sound-registry'
import NativeNotifications from '../../../src/native-notifications'
import {Notifier} from '../lib/main'

xdescribe("UnreadNotifications", function UnreadNotifications() {
  beforeEach(() => {
    this.notifier = new Notifier();

    const inbox = new Category({id: "l1", name: "inbox", displayName: "Inbox"})
    const archive = new Category({id: "l2", name: "archive", displayName: "Archive"})

    spyOn(CategoryStore, "getStandardCategory").andReturn(inbox);

    const account = AccountStore.accounts()[0];

    this.threadA = new Thread({
      id: 'A',
      categories: [inbox],
    });
    this.threadB = new Thread({
      id: 'B',
      categories: [archive],
    });

    this.msg1 = new Message({
      unread: true,
      date: new Date(),
      from: [new Contact({name: 'Ben', email: 'benthis.example.com'})],
      subject: "Hello World",
      threadId: "A",
    });
    this.msgNoSender = new Message({
      unread: true,
      date: new Date(),
      from: [],
      subject: "Hello World",
      threadId: "A",
    });
    this.msg2 = new Message({
      unread: true,
      date: new Date(),
      from: [new Contact({name: 'Mark', email: 'markthis.example.com'})],
      subject: "Hello World 2",
      threadId: "A",
    });
    this.msg3 = new Message({
      unread: true,
      date: new Date(),
      from: [new Contact({name: 'Ben', email: 'benthis.example.com'})],
      subject: "Hello World 3",
      threadId: "A",
    });
    this.msg4 = new Message({
      unread: true,
      date: new Date(),
      from: [new Contact({name: 'Ben', email: 'benthis.example.com'})],
      subject: "Hello World 4",
      threadId: "A",
    });
    this.msg5 = new Message({
      unread: true,
      date: new Date(),
      from: [new Contact({name: 'Ben', email: 'benthis.example.com'})],
      subject: "Hello World 5",
      threadId: "A",
    });
    this.msgUnreadButArchived = new Message({
      unread: true,
      date: new Date(),
      from: [new Contact({name: 'Mark', email: 'markthis.example.com'})],
      subject: "Hello World 2",
      threadId: "B",
    });
    this.msgRead = new Message({
      unread: false,
      date: new Date(),
      from: [new Contact({name: 'Mark', email: 'markthis.example.com'})],
      subject: "Hello World Read Already",
      threadId: "A",
    });
    this.msgOld = new Message({
      unread: true,
      date: new Date(2000, 1, 1),
      from: [new Contact({name: 'Mark', email: 'markthis.example.com'})],
      subject: "Hello World Old",
      threadId: "A",
    });
    this.msgFromMe = new Message({
      unread: true,
      date: new Date(),
      from: [account.me()],
      subject: "A Sent Mail!",
      threadId: "A",
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

    this.notification = jasmine.createSpyObj('notification', ['close']);
    spyOn(NativeNotifications, 'displayNotification').andReturn(this.notification);

    spyOn(Promise, 'props').andCallFake((dict) => {
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
  })

  it("should create a Notification if there is one unread message", () => {
    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({message: [this.msgRead, this.msg1]})
      .then(() => {
        advanceClock(2000)
        expect(NativeNotifications.displayNotification).toHaveBeenCalled()
        const options = NativeNotifications.displayNotification.mostRecentCall.args[0]
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
  });

  it("should create multiple Notifications if there is more than one but less than five unread messages", () => {
    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({message: [this.msg1, this.msg2, this.msg3]})
      .then(() => {
        // Need to call advance clock twice because we call setTimeout twice
        advanceClock(2000)
        advanceClock(2000)
        expect(NativeNotifications.displayNotification.callCount).toEqual(3)
      });
    });
  });

  it("should create Notifications in the order of messages received", () => {
    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({message: [this.msg1, this.msg2]})
      .then(() => {
        advanceClock(2000);
        return this.notifier._onNewMailReceived({message: [this.msg3, this.msg4]});
      })
      .then(() => {
        advanceClock(2000);
        advanceClock(2000);
        expect(NativeNotifications.displayNotification.callCount).toEqual(4);
        const subjects = NativeNotifications.displayNotification.calls.map((call) => {
          return call.args[0].subtitle;
        });
        const expected = [this.msg1, this.msg2, this.msg3, this.msg4]
          .map((msg) => msg.subject);
        expect(subjects).toEqual(expected);
      });
    });
  });

  it("should create a Notification if there are five or more unread messages", () => {
    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({
        message: [this.msg1, this.msg2, this.msg3, this.msg4, this.msg5]})
      .then(() => {
        advanceClock(2000)
        expect(NativeNotifications.displayNotification).toHaveBeenCalled()
        expect(NativeNotifications.displayNotification.mostRecentCall.args).toEqual([{
          title: '5 Unread Messages',
          tag: 'unread-update',
        }])
      });
    });
  });

  it("should create a Notification correctly, even if new mail has no sender", () => {
    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({message: [this.msgNoSender]})
      .then(() => {
        expect(NativeNotifications.displayNotification).toHaveBeenCalled()

        const options = NativeNotifications.displayNotification.mostRecentCall.args[0]
        delete options.onActivate;
        expect(options).toEqual({
          title: 'Unknown',
          subtitle: 'Hello World',
          body: undefined,
          canReply: true,
          tag: 'unread-update',
        })
      });
    });
  });

  it("should not create a Notification if there are no new messages", () => {
    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({message: []})
      .then(() => {
        expect(NativeNotifications.displayNotification).not.toHaveBeenCalled()
      });
    });

    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({})
      .then(() => {
        expect(NativeNotifications.displayNotification).not.toHaveBeenCalled()
      });
    });
  });

  it("should not notify about unread messages that are outside the inbox", () => {
    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({message: [this.msgUnreadButArchived, this.msg1]})
      .then(() => {
        expect(NativeNotifications.displayNotification).toHaveBeenCalled()
        const options = NativeNotifications.displayNotification.mostRecentCall.args[0]
        delete options.onActivate;
        expect(options).toEqual({
          title: 'Ben',
          subtitle: 'Hello World',
          body: undefined,
          canReply: true,
          tag: 'unread-update',
        })
      });
    });
  });

  it("should not create a Notification if the new messages are read", () => {
    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({message: [this.msgRead]})
      .then(() => {
        expect(NativeNotifications.displayNotification).not.toHaveBeenCalled()
      });
    });
  });

  it("should not create a Notification if the new messages are actually old ones", () => {
    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({message: [this.msgOld]})
      .then(() => {
        expect(NativeNotifications.displayNotification).not.toHaveBeenCalled()
      });
    });
  });

  it("should not create a Notification if the new message is one I sent", () => {
    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({message: [this.msgFromMe]})
      .then(() => {
        expect(NativeNotifications.displayNotification).not.toHaveBeenCalled()
      });
    });
  });

  it("clears notifications when a thread is read", () => {
    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({message: [this.msg1]})
      .then(() => {
        expect(NativeNotifications.displayNotification).toHaveBeenCalled();
        expect(this.notification.close).not.toHaveBeenCalled();
        this.notifier._onThreadIsRead(this.threadA);
        expect(this.notification.close).toHaveBeenCalled();
      });
    });
  });

  it("detects changes that may be a thread being read", () => {
    const unreadThread = { unread: true };
    const readThread = { unread: false };
    spyOn(this.notifier, '_onThreadIsRead');
    this.notifier._onDatabaseUpdated({ objectClass: 'Thread', objects: [unreadThread, readThread]});
    expect(this.notifier._onThreadIsRead.calls.length).toEqual(1);
    expect(this.notifier._onThreadIsRead).toHaveBeenCalledWith(readThread);
  });

  it("should play a sound when it gets new mail", () => {
    spyOn(NylasEnv.config, "get").andCallFake((config) => {
      if (config === "core.notifications.enabled") return true
      if (config === "core.notifications.sounds") return true
      return undefined;
    });

    spyOn(SoundRegistry, "playSound");
    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({message: [this.msg1]})
      .then(() => {
        expect(NylasEnv.config.get.calls[1].args[0]).toBe("core.notifications.sounds");
        expect(SoundRegistry.playSound).toHaveBeenCalledWith("new-mail");
      });
    });
  });

  it("should not play a sound if the config is off", () => {
    spyOn(NylasEnv.config, "get").andCallFake((config) => {
      if (config === "core.notifications.enabled") return true;
      if (config === "core.notifications.sounds") return false;
      return undefined;
    });
    spyOn(SoundRegistry, "playSound")
    waitsForPromise(() => {
      return this.notifier._onNewMailReceived({message: [this.msg1]})
      .then(() => {
        expect(NylasEnv.config.get.calls[1].args[0]).toBe("core.notifications.sounds");
        expect(SoundRegistry.playSound).not.toHaveBeenCalled()
      });
    });
  });

  it("should not play a sound if other notiications are still in flight", () => {
    spyOn(NylasEnv.config, "get").andCallFake((config) => {
      if (config === "core.notifications.enabled") return true;
      if (config === "core.notifications.sounds") return true;
      return undefined;
    });
    waitsForPromise(() => {
      spyOn(SoundRegistry, "playSound")
      return this.notifier._onNewMailReceived({message: [this.msg1, this.msg2]}).then(() => {
        expect(SoundRegistry.playSound).toHaveBeenCalled();
        SoundRegistry.playSound.reset();
        return this.notifier._onNewMailReceived({message: [this.msg3]}).then(() => {
          expect(SoundRegistry.playSound).not.toHaveBeenCalled();
        });
      });
    });
  });

  describe("when the message has no matching thread", () => {
    beforeEach(() => {
      this.msgNoThread = new Message({
        unread: true,
        date: new Date(),
        from: [new Contact({name: 'Ben', email: 'benthis.example.com'})],
        subject: "Hello World",
        threadId: "missing",
      });
    });

    it("should not create a Notification, since it cannot be determined whether the message is in the Inbox", () => {
      waitsForPromise(() => {
        return this.notifier._onNewMailReceived({message: [this.msgNoThread]})
        .then(() => {
          advanceClock(2000)
          expect(NativeNotifications.displayNotification).not.toHaveBeenCalled()
        });
      });
    });

    it("should call _onNewMessagesMissingThreads to try displaying a notification again in 10 seconds", () => {
      waitsForPromise(() => {
        spyOn(this.notifier, '_onNewMessagesMissingThreads')
        return this.notifier._onNewMailReceived({message: [this.msgNoThread]})
        .then(() => {
          advanceClock(2000)
          expect(this.notifier._onNewMessagesMissingThreads).toHaveBeenCalledWith([this.msgNoThread])
        });
      });
    });
  });

  describe("_onNewMessagesMissingThreads", () => {
    beforeEach(() => {
      this.msgNoThread = new Message({
        unread: true,
        date: new Date(),
        from: [new Contact({name: 'Ben', email: 'benthis.example.com'})],
        subject: "Hello World",
        threadId: "missing",
      });
      spyOn(this.notifier, '_onNewMailReceived')
      this.notifier._onNewMessagesMissingThreads([this.msgNoThread])
      advanceClock(2000)
    });

    it("should wait 10 seconds and then re-query for threads", () => {
      expect(DatabaseStore.find).not.toHaveBeenCalled()
      this.msgNoThread.threadId = "A"
      advanceClock(10000)
      expect(DatabaseStore.find).toHaveBeenCalled()
      advanceClock()
      expect(this.notifier._onNewMailReceived).toHaveBeenCalledWith({message: [this.msgNoThread], thread: [this.threadA]})
    });

    it("should do nothing if the threads still can't be found", () => {
      expect(DatabaseStore.find).not.toHaveBeenCalled()
      advanceClock(10000)
      expect(DatabaseStore.find).toHaveBeenCalled()
      advanceClock()
      expect(this.notifier._onNewMailReceived).not.toHaveBeenCalled()
    });
  });
});
