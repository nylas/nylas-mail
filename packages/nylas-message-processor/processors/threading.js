// const _ = require('underscore');

class ThreadingProcessor {
  pickMatchingThread(message, threads) {
    return threads.pop();

    // This logic is tricky... Used to say that threads with >2 participants in common
    // should be treated as the same, plus special cases for when it's a 1<>1
    // conversation. Put it back soonish.

    // const messageEmails = _.uniq([].concat(message.to, message.cc, message.from).map(p => p.email));
    // console.log(`Found ${threads.length} candidate threads for message with subject: ${message.subject}`)
    //
    // for (const thread of threads) {
    //   const threadEmails = _.uniq([].concat(thread.participants).map(p => p.email));
    //   console.log(`Intersection: ${_.intersection(threadEmails, messageEmails).join(',')}`)
    //
    //   if (_.intersection(threadEmails, messageEmails) >= threadEmails.length * 0.9) {
    //     return thread;
    //   }
    // }
    //
    // return null;
  }

  cleanSubject(subject = "") {
    const regex = new RegExp(/^((re|fw|fwd|aw|wg|undeliverable|undelivered):\s*)+/ig);
    return subject.replace(regex, () => "");
  }

  findOrCreateByMatching(db, message) {
    const {Thread} = db

    // in the future, we should look at In-reply-to. Problem is it's a single-
    // directional linked list, and we don't scan the mailbox from oldest=>newest,
    // but from newest->oldest, so when we ingest a message it's very unlikely
    // we have the "In-reply-to" message yet.

    return Thread.findAll({
      where: {
        subject: this.cleanSubject(message.subject),
      },
      order: [
        ['id', 'DESC'],
      ],
      limit: 50,
    }).then((threads) =>
      this.pickMatchingThread(message, threads) || Thread.build({})
    )
  }

  findOrCreateByThreadId({Thread}, threadId) {
    return Thread.find({where: {threadId}}).then((thread) => {
      return thread || Thread.build({threadId});
    })
  }

  processMessage({db, message}) {
    let findOrCreateThread = null;
    if (message.headers['x-gm-thrid']) {
      findOrCreateThread = this.findOrCreateByThreadId(db, message.headers['x-gm-thrid'])
    } else {
      findOrCreateThread = this.findOrCreateByMatching(db, message)
    }

    return Promise.props({
      thread: findOrCreateThread,
      sentCategory: db.Category.find({where: {role: 'sent'}}),
    })
    .then(({thread, sentCategory}) => {
      thread.addMessage(message);

      // update the basic properties of the thread
      thread.accountId = message.accountId;

      // update the participants on the thread
      const threadParticipants = [].concat(thread.participants);
      const threadEmails = thread.participants.map(p => p.email);

      for (const p of [].concat(message.to, message.cc, message.from)) {
        if (!threadEmails.includes(p.email)) {
          threadParticipants.push(p);
          threadEmails.push(p.email);
        }
      }
      thread.participants = threadParticipants;

      // update starred and unread
      if (thread.starredCount == null) { thread.starredCount = 0; }
      thread.starredCount += message.starred ? 1 : 0;
      if (thread.unreadCount == null) { thread.unreadCount = 0; }
      thread.unreadCount += message.unread ? 1 : 0;

      // update dates
      if (!thread.lastMessageDate || (message.date > thread.lastMessageDate)) {
        thread.lastMessageDate = message.date;
        thread.snippet = message.snippet;
        thread.subject = this.cleanSubject(message.subject);
      }
      if (!thread.firstMessageDate || (message.date < thread.firstMessageDate)) {
        thread.firstMessageDate = message.date;
      }
      const sentCategoryId = sentCategory ? sentCategory.id : null;
      if ((message.categoryId === sentCategoryId) && (message.date > thread.lastMessageSentDate)) {
        thread.lastMessageSentDate = message.date;
      }
      if ((message.categoryId !== sentCategoryId) && (message.date > thread.lastMessageReceivedDate)) {
        thread.lastMessageReceivedDate = message.date;
      }

      // update categories and sav
      return thread.hasCategory(message.categoryId).then((hasCategory) => {
        if (!hasCategory) {
          thread.addCategory(message.categoryId)
        }
        return thread.save().then((saved) => {
          message.threadId = saved.id;
          return message;
        });
      });
    });
  }
}

const processor = new ThreadingProcessor();

module.exports = {
  processMessage: processor.processMessage.bind(processor),
  order: 1,
};
