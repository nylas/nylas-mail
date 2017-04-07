// straight translated from the Nylas Sync Engine python codebase, see
// https://github.com/nylas/cloud-core/blob/7db949fec9447b73e2ba9485d8903380414e8223/sync-engine/inbox/util/misc.py#L175-L183
// for original!
function cleanSubject(subject = "") {
  const regex = new RegExp(/^((re|fw|fwd|aw|wg|undeliverable|undelivered):\s*)+/ig);
  return subject.replace(regex, () => "");
}

function emptyThread({Thread, accountId}, options = {}) {
  const t = Thread.build(Object.assign({accountId}, options))
  t.folders = [];
  t.labels = [];
  t.participants = [];
  return t;
}

async function findOrBuildByReferences(db, message, transaction) {
  const {Thread, Reference, Label, Folder} = db;

  let matchingRef = null;

  // If we have a thread that matches the new message, at least one element
  // of the new message's references will match an existing reference we've
  // already synced and associated with the correct thread.
  if (message.headerMessageId) {
    matchingRef = await Reference.findOne({
      where: {
        rfc2822MessageId: message.references,
      },
      include: [
        { model: Thread, include: [{model: Label}, {model: Folder}]},
      ],
      transaction,
    });
  }

  if (matchingRef && !matchingRef.thread) {
    throw new Error(`Reference not properly cleaned up`)
  }
  return matchingRef ? matchingRef.thread : emptyThread(db, {});
}

async function findOrBuildByRemoteThreadId(db, remoteThreadId, transaction) {
  const {Thread, Label, Folder} = db;
  const existing = await Thread.find({
    where: {remoteThreadId},
    include: [{model: Label}, {model: Folder}],
    transaction,
  });
  return existing || emptyThread(db, {remoteThreadId});
}

async function detectThread({db, messageValues, transaction}) {
  if (!(messageValues.labels instanceof Array)) {
    throw new Error("detectThread expects labels to be an inflated array.");
  }
  if (!messageValues.folder) {
    throw new Error("detectThread expects folder value to be present.");
  }

  let thread = null;
  if (messageValues.gThrId) {
    thread = await findOrBuildByRemoteThreadId(db, messageValues.gThrId, transaction)
  } else {
    thread = await findOrBuildByReferences(db, messageValues, transaction)
  }

  if (!(thread.labels instanceof Array)) {
    throw new Error("detectThread expects thread.labels to be an inflated array.");
  }
  if (!(thread.folders instanceof Array)) {
    throw new Error("detectThread expects thread.folders to be an inflated array.");
  }

  // update the basic properties of the thread
  thread.accountId = messageValues.accountId;

  // Threads may, locally, have the ID of any message within the thread.
  // Message IDs are globally unique within an account---but not necessarily
  // across accounts, due to hashing.
  if (!thread.id) {
    thread.id = `t:${messageValues.id}`
  }

  thread.subject = cleanSubject(messageValues.subject);
  await thread.updateFromMessages({messages: [messageValues], transaction});
  return thread;
}

module.exports = detectThread
