function cleanSubject(subject = "") {
  const regex = new RegExp(/^((re|fw|fwd|aw|wg|undeliverable|undelivered):\s*)+/ig);
  return subject.replace(regex, () => "");
}

// straight translated from the Nylas Sync Engine python codebase, see
// https://github.com/nylas/cloud-core/blob/7db949fec9447b73e2ba9485d8903380414e8223/sync-engine/inbox/util/threading.py#L11-L71
// for original!
function pickMatchingThread(message, threads, maxThreadLength) {
  // console.log({
  //   num_candidate_threads: threads.length,
  //   message_subject: message.subject,
  // }, `Found candidate threads for message`);

  // A lot of people BCC some address when sending mass emails so exclude bcc
  // from participants.
  const newMsgEmails = new Set([].concat(message.to, message.cc, message.from).map(p => p.email));
  for (const thread of threads) {
    for (const existingMsg of thread.messages) {
      const existingMsgEmails = new Set([].concat(existingMsg.to, existingMsg.cc, existingMsg.from).map(p => p.email));

      // A conversation takes place between two or more persons. Are there more
      // than two participants in common in this thread? If yes, it's probably
      // a related thread.
      const intersection = new Set([...newMsgEmails].filter(p => existingMsgEmails.has(p)));
      if (intersection.size >= 2) {
        // No need to loop through the rest of the messages in the thread
        if (thread.messages.length >= maxThreadLength) {
          break;
        } else return thread;
      }

      // handle the case where someone is self-sending an email
      if (!message.from || !message.to) return null;

      const existingMsgFromEmails = new Set(existingMsg.from.map(p => p.email));
      const existingMsgToEmails = new Set(existingMsg.to.map(p => p.email));
      const newMsgFromEmails = new Set(message.from.map(p => p.email));
      const newMsgToEmails = new Set(message.to.map(p => p.email));
      if (newMsgToEmails.size === 1 && newMsgFromEmails === newMsgToEmails
          && existingMsgFromEmails === existingMsgToEmails
          && newMsgToEmails === existingMsgFromEmails) {
        if (thread.messages.length >= maxThreadLength) {
          break;
        } else return thread;
      }
    }
  }

  return null;
}

function emptyThread({Thread, accountId}, options = {}) {
  const t = Thread.build(Object.assign({accountId}, options))
  t.folders = [];
  t.labels = [];
  t.participants = [];
  return t;
}

async function findOrBuildByMatching(db, message) {
  const {Thread, Label, Folder, Message} = db;

  // In the future, we should look at In-reply-to. Problem is it's a single-
  // directional linked list, and we don't scan the mailbox from
  // oldest=>newest, but from newest->oldest, so when we ingest a message it's
  // very unlikely we have the "In-reply-to" message yet.

  const possibleThreads = await Thread.findAll({
    where: {
      subject: cleanSubject(message.subject),
    },
    order: [
      ['id', 'DESC'],
    ],
    limit: 10,
    include: [{model: Label}, {model: Folder},
              {model: Message, attributes: ["to", "cc", "from"]}],
  });

  return pickMatchingThread(message, possibleThreads, Thread.MAX_THREAD_LENGTH)
         || emptyThread(db, {});
}

async function findOrBuildByRemoteThreadId(db, remoteThreadId) {
  const {Thread, Label, Folder} = db;
  const existing = await Thread.find({
    where: {remoteThreadId},
    include: [{model: Label}, {model: Folder}],
  });
  return existing || emptyThread(db, {remoteThreadId});
}

async function detectThread({db, message}) {
  if (!(message.labels instanceof Array)) {
    throw new Error("detectThread expects labels to be an inflated array.");
  }
  if (!message.folder) {
    throw new Error("detectThread expects folder value to be present.");
  }

  let thread = null;
  if (message.headers['x-gm-thrid']) {
    thread = await findOrBuildByRemoteThreadId(db, message.headers['x-gm-thrid'])
  } else {
    thread = await findOrBuildByMatching(db, message)
  }

  if (!(thread.labels instanceof Array)) {
    throw new Error("detectThread expects thread.labels to be an inflated array.");
  }
  if (!(thread.folders instanceof Array)) {
    throw new Error("detectThread expects thread.folders to be an inflated array.");
  }

  // update the basic properties of the thread
  thread.accountId = message.accountId;

  // Threads may, locally, have the ID of any message within the thread.
  // Message IDs are globally unique within an account---but not necessarily
  // across accounts, due to hashing.
  if (!thread.id) {
    thread.id = `t:${message.id}`
  }

  thread.subject = cleanSubject(message.subject);
  await thread.updateFromMessage(message);
  return thread;
}

module.exports = detectThread
