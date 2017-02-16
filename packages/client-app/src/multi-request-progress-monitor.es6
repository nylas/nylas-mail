import fs from 'fs';

export default class MultiRequestProgressMonitor {
  constructor() {
    this._requests = {};
    this._expected = {};
  }

  add(filepath, filesize, request) {
    this._requests[filepath] = request
    this._expected[filepath] = filesize || fs.statSync(filepath).size || 0;
  }

  remove(filepath) {
    delete this._requests[filepath];
    delete this._expected[filepath];
  }

  requests() {
    return Object.keys(this._requests).map(k => this._requests[k]);
  }

  value() {
    let sent = 0;
    let expected = 1;
    for (const filepath of Object.keys(this._requests)) {
      const request = this._requests[filepath];
      if (request.req && request.req.connection) {
        sent += request.req.connection._bytesDispatched || 0
      }
      expected += this._expected[filepath];
    }
    return sent / expected;
  }
}
