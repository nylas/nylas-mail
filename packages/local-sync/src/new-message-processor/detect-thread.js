// const _ = require('underscore');


function pickMatchingThread(message, threads) {
  return threads.pop();

  // This logic is tricky... Used to say that threads with >2 participants in common
  // should be treated as the same, plus special cases for when it's a 1<>1
  // conversation. Put it back soonish.

  // const messageEmails = _.uniq([].concat(message.to, message.cc, message.from).map(p => p.email));
  // logger.info({
  //   num_candidate_threads: threads.length,
  //   message_subject: message.subject,
  // }, `Found candidate threads for message`)
  //
  // for (const thread of threads) {
  //   const threadEmails = _.uniq([].concat(thread.participants).map(p => p.email));
  //   logger.info(`Intersection: ${_.intersection(threadEmails, messageEmails).join(',')}`)
  //
  //   if (_.intersection(threadEmails, messageEmails) >= threadEmails.length * 0.9) {
  //     return thread;
  //   }
  // }
  //
  // return null;
}

function cleanSubject(subject = "") {
  const regex = new RegExp(/^((re|fw|fwd|aw|wg|undeliverable|undelivered):\s*)+/ig);
  return subject.replace(regex, () => "");
}

function emptyThread({Thread, accountId}, options = {}) {
  const t = Thread.build(Object.assign({accountId}, options))
  t.folders = [];
  t.labels = [];
  return Promise.resolve(t)
}

function findOrBuildByMatching(db, message) {
  const {Thread, Label, Folder} = db

  // in the future, we should look at In-reply-to. Problem is it's a single-
  // directional linked list, and we don't scan the mailbox from oldest=>newest,
  // but from newest->oldest, so when we ingest a message it's very unlikely
  // we have the "In-reply-to" message yet.

  return Thread.findAll({
    where: {
      subject: cleanSubject(message.subject),
    },
    order: [
      ['id', 'DESC'],
    ],
    limit: 10,
    include: [{model: Label}, {model: Folder}],
  }).then((threads) =>
    pickMatchingThread(message, threads) || emptyThread(db, {})
  )
}

function findOrBuildByRemoteThreadId(db, remoteThreadId) {
  const {Thread, Label, Folder} = db;
  return Thread.find({
    where: {remoteThreadId},
    include: [{model: Label}, {model: Folder}],
  }).then((thread) => {
    return thread || emptyThread(db, {remoteThreadId})
  })
}

function detectThread({db, message}) {
  if (!(message.labels instanceof Array)) {
    throw new Error("Threading processMessage expects labels to be an inflated array.");
  }
  if (!message.folder) {
    throw new Error("Threading processMessage expects folder value to be present.");
  }

  let findOrBuildThread = null;
  if (message.headers['x-gm-thrid']) {
    findOrBuildThread = findOrBuildByRemoteThreadId(db, message.headers['x-gm-thrid'])
  } else {
    findOrBuildThread = findOrBuildByMatching(db, message)
  }

  return findOrBuildThread.then((thread) => {
    if (!(thread.labels instanceof Array)) {
      throw new Error("Threading processMessage expects thread.labels to be an inflated array.");
    }
    if (!(thread.folders instanceof Array)) {
      throw new Error("Threading processMessage expects thread.folders to be an inflated array.");
    }

    // update the basic properties of the thread
    thread.accountId = message.accountId;
    // Threads may, locally, have the ID of any message within the thread
    // (message IDs are globally unique, even across accounts!)
    if (!thread.id) {
      thread.id = `t:${message.id}`
    }

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
      thread.subject = cleanSubject(message.subject);
    }
    if (!thread.firstMessageDate || (message.date < thread.firstMessageDate)) {
      thread.firstMessageDate = message.date;
    }

    const isSent = (
      message.folder.role === 'sent' ||
      !!message.labels.find(l => l.role === 'sent')
    )

    if (isSent && ((message.date > thread.lastMessageSentDate) || !thread.lastMessageSentDate)) {
      thread.lastMessageSentDate = message.date;
    }
    if (!isSent && ((message.date > thread.lastMessageReceivedDate) || !thread.lastMessageReceivedDate)) {
      thread.lastMessageReceivedDate = message.date;
    }

    return thread.save()
    .then((saved) => {
      const promises = []
      // update folders and labels
      if (!saved.folders.find(f => f.id === message.folderId)) {
        promises.push(saved.addFolder(message.folder))
      }
      for (const label of message.labels) {
        if (!saved.labels.find(l => l.id === label)) {
          promises.push(saved.addLabel(label))
        }
      }
      return Promise.all(promises).thenReturn(saved)
    })
  });
}

module.exports = detectThread
