export default class SharedFileManager {
  constructor() {
    this._inflight = {};
  }

  processWillWriteFile(filePath) {
    this._inflight[filePath] += 1;
  }

  processDidWriteFile(filePath) {
    this._inflight[filePath] -= 1;
  }

  processCanReadFile(filePath) {
    return (!this._inflight[filePath]) || (this._inflight[filePath] === 0);
  }
}
