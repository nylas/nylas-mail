
// "Source" is a hack so that the error matches the ones used by node-imap

class IMAPConnectionNotReadyError extends Error {
  constructor(funcName) {
    super(`${funcName} - You must call connect() first.`);
    this.source = 'socket';
  }
}

class IMAPConnectionEndedError extends Error {
  constructor(msg = "The IMAP Connection was ended.") {
    super(msg);
    this.source = 'socket';
  }
}

module.exports = {
  IMAPConnectionNotReadyError,
  IMAPConnectionEndedError,
};
