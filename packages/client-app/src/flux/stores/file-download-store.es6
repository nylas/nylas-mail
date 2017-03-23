import _ from 'underscore';
import os from 'os';
import fs from 'fs';
import path from 'path';
import {exec} from 'child_process';
import {remote, shell} from 'electron';
import mkdirp from 'mkdirp';
import progress from 'request-progress';
import NylasStore from 'nylas-store';
import Actions from '../actions';
import NylasAPI from '../nylas-api';
import NylasAPIRequest from '../nylas-api-request';


Promise.promisifyAll(fs);
const mkdirpAsync = Promise.promisify(mkdirp);

const State = {
  Unstarted: 'unstarted',
  Downloading: 'downloading',
  Finished: 'finished',
  Failed: 'failed',
};

// TODO make this list more exhaustive
const NonPreviewableExtensions = [
  'jpg',
  'bmp',
  'gif',
  'png',
  'jpeg',
  'zip',
  'tar',
  'gz',
  'bz2',
  'dmg',
  'exe',
  'ics',
]

const THUMBNAIL_WIDTH = 320


// Expose the Download class for our tests, and possibly for other things someday
export class Download {
  static State = State

  constructor({accountId, fileId, targetPath, filename, filesize, progressCallback, retryWithBackoff}) {
    this.accountId = accountId;
    this.fileId = fileId;
    this.targetPath = targetPath;
    this.filename = filename;
    this.filesize = filesize;
    this.progressCallback = progressCallback;
    this.retryWithBackoff = retryWithBackoff || false;
    this.timeout = 15000;
    this.maxTimeout = 2 * 60 * 1000;
    this.attempts = 0;
    this.maxAttempts = 10;
    if (!this.accountId) {
      throw new Error("Download.constructor: You must provide a non-empty accountId.");
    }
    if (!this.filename || this.filename.length === 0) {
      throw new Error("Download.constructor: You must provide a non-empty filename.");
    }
    if (!this.fileId) {
      throw new Error("Download.constructor: You must provide a fileID to download.");
    }
    if (!this.targetPath) {
      throw new Error("Download.constructor: You must provide a target path to download.");
    }

    this.percent = 0;
    this.promise = null;
    this.state = State.Unstarted;
  }

  // We need to pass a plain object so we can have fresh references for the
  // React views while maintaining the single object with the running
  // request.
  data() {
    return Object.freeze(_.clone({
      state: this.state,
      fileId: this.fileId,
      percent: this.percent,
      filename: this.filename,
      filesize: this.filesize,
      targetPath: this.targetPath,
    }));
  }

  run() {
    // If run has already been called, return the existing promise. Never
    // initiate multiple downloads for the same file
    if (this.promise) { return this.promise; }

    // Note: we must resolve or reject with `this`
    this.promise = new Promise((resolve, reject) => {
      const stream = fs.createWriteStream(this.targetPath);
      this.state = State.Downloading;

      let startRequest = null;

      const before = Date.now();

      const onFailed = (err) => {
        Actions.recordPerfMetric({
          action: 'file-download-failed',
          accountId: this.accountId,
          actionTimeMs: Date.now() - before,
          maxValue: 10 * 60 * 1000,
        })
        this.request = null;
        stream.end();
        if (!this.retryWithBackoff || this.attempts >= this.maxAttempts) {
          this.state = State.Failed;
          if (fs.existsSync(this.targetPath)) {
            fs.unlinkSync(this.targetPath);
          }
          reject(err);
          return;
        }

        this.timeout = Math.min(this.maxTimeout, this.timeout * 2);
        startRequest();
      };

      const onSuccess = () => {
        Actions.recordPerfMetric({
          action: 'file-download-succeeded',
          accountId: this.accountId,
          actionTimeMs: Date.now() - before,
          maxValue: 10 * 60 * 1000,
        })
        this.request = null;
        stream.end();
        this.state = State.Finished;
        this.percent = 100;
        resolve(this);
      };

      startRequest = () => {
        console.info(`starting download with ${this.timeout}ms timeout`);
        const request = new NylasAPIRequest({
          api: NylasAPI,
          options: {
            json: false,
            path: `/files/${this.fileId}/download`,
            accountId: this.accountId,
            encoding: null, // Tell `request` not to parse the response data
            timeout: this.timeout,
            started: (req) => {
              this.attempts += 1;
              this.request = req;
              return progress(this.request, {throtte: 250})
              .on('progress', (prog) => {
                this.percent = prog.percent;
                this.progressCallback();
              })

              // This is a /socket/ error event, not an HTTP error event. It fires
              // when the conn is dropped, user if offline, but not on HTTP status codes.
              // It is sometimes called in place of "end", not before or after.
              .on('error', onFailed)

              .on('end', () => {
                if (this.state === State.Failed) { return; }

                const {response} = this.request
                const statusCode = response ? response.statusCode : null;
                if ([200, 202, 204].includes(statusCode)) {
                  onSuccess();
                } else {
                  onFailed(new Error(`Server returned a ${statusCode}`));
                }
              })

              .pipe(stream);
            },
          },
        });

        request.run()
      };

      startRequest();
    });
    return this.promise
  }

  ensureClosed() {
    if (this.request) {
      this.request.abort()
    }
  }
}


class FileDownloadStore extends NylasStore {

  constructor() {
    super()
    this.listenTo(Actions.fetchFile, this._fetch);
    this.listenTo(Actions.fetchAndOpenFile, this._fetchAndOpen);
    this.listenTo(Actions.fetchAndSaveFile, this._fetchAndSave);
    this.listenTo(Actions.fetchAndSaveAllFiles, this._fetchAndSaveAll);
    this.listenTo(Actions.abortFetchFile, this._abortFetchFile);

    this._downloads = {};
    this._filePreviewPaths = {};
    this._downloadDirectory = path.join(NylasEnv.getConfigDirPath(), 'downloads');
    mkdirp(this._downloadDirectory);
  }

  // Returns a path on disk for saving the file. Note that we must account
  // for files that don't have a name and avoid returning <downloads/dir/"">
  // which causes operations to happen on the directory (badness!)
  //
  pathForFile(file) {
    if (!file) { return null; }
    return path.join(this._downloadDirectory, file.id, file.safeDisplayName());
  }

  getDownloadDataForFile(fileId) {
    const download = this._downloads[fileId]
    if (!download) { return null; }
    return download.data()
  }

  // Returns a hash of download objects keyed by fileId
  //
  getDownloadDataForFiles(fileIds = []) {
    const downloadData = {};
    fileIds.forEach((fileId) => {
      downloadData[fileId] = this.getDownloadDataForFile(fileId);
    });
    return downloadData;
  }

  previewPathsForFiles(fileIds = []) {
    const previewPaths = {};
    fileIds.forEach((fileId) => {
      previewPaths[fileId] = this.previewPathForFile(fileId);
    });
    return previewPaths;
  }

  previewPathForFile(fileId) {
    return this._filePreviewPaths[fileId];
  }

  // Returns a promise with a Download object, allowing other actions to be
  // daisy-chained to the end of the download operation.
  _runDownload(file) {
    const targetPath = this.pathForFile(file);

    // is there an existing download for this file? If so,
    // return that promise so users can chain to the end of it.
    let download = this._downloads[file.id];
    if (download) { return download.run(); }

    // create a new download for this file
    download = new Download({
      accountId: file.accountId,
      fileId: file.id,
      filesize: file.size,
      filename: file.displayName(),
      targetPath,
      progressCallback: () => this.trigger(),
      retryWithBackoff: true,
    });

    // Do we actually need to queue and run the download? Queuing a download
    // for an already-downloaded file has side-effects, like making the UI
    // flicker briefly.
    return this._prepareFolder(file).then(() => {
      return this._checkForDownloadedFile(file)
      .then((alreadyHaveFile) => {
        if (alreadyHaveFile) {
          // If we have the file, just resolve with a resolved download representing the file.
          download.promise = Promise.resolve();
          download.state = State.Finished;
          return Promise.resolve(download);
        }
        this._downloads[file.id] = download;
        this.trigger();
        return download.run().finally(() => {
          download.ensureClosed();
          if (download.state === State.Failed) {
            delete this._downloads[file.id];
          }
          this.trigger();
        });
      })
      .then(() => this._generatePreview(file))
      .then(() => Promise.resolve(download))
    });
  }

  _generatePreview(file) {
    if (process.platform !== 'darwin') { return Promise.resolve() }
    if (!NylasEnv.config.get('core.attachments.displayFilePreview')) {
      return Promise.resolve()
    }
    if (NonPreviewableExtensions.includes(file.displayExtension())) {
      return Promise.resolve()
    }

    const filePath = this.pathForFile(file)
    const previewPath = `${filePath}.png`
    return fs.accessAsync(filePath, fs.F_OK)
    .then(() => {
      fs.accessAsync(previewPath, fs.F_OK)
      .then(() => {
        // If the preview file already exists, set our state and bail
        this._filePreviewPaths[file.id] = previewPath
        this.trigger()
      })
      .catch(() => {
        // If the preview file doesn't exist yet, generate it
        const fileDir = `"${path.dirname(filePath)}"`
        const escapedPath = `"${filePath}"`
        return new Promise((resolve) => {
          const previewSize = THUMBNAIL_WIDTH * (11 / 8.5)
          exec(`qlmanage -t -f ${window.devicePixelRatio} -s ${previewSize} -o ${fileDir} ${escapedPath}`, (error, stdout, stderr) => {
            if (error) {
              // Ignore errors, we don't really mind if we can't generate a preview
              // for a file
              NylasEnv.reportError(error)
              resolve()
              return
            }
            if (stdout.match(/No thumbnail created/i) || stderr) {
              resolve()
              return
            }
            this._filePreviewPaths[file.id] = previewPath
            this.trigger()
            resolve()
          })
        })
      })
    })
    // If the file doesn't exist, ignore the error.
    .catch(() => Promise.resolve())
  }

  // Returns a promise that resolves with true or false. True if the file has
  // been downloaded, false if it should be downloaded.
  //
  _checkForDownloadedFile(file) {
    return fs.statAsync(this.pathForFile(file))
    .then((stats) => {
      return Promise.resolve(stats.size >= file.size);
    })
    .catch(() => {
      return Promise.resolve(false);
    })
  }

  // Checks that the folder for the download is ready. Returns a promise that
  // resolves when the download directory for the file has been created.
  //
  _prepareFolder(file) {
    const targetFolder = path.join(this._downloadDirectory, file.id);
    return fs.statAsync(targetFolder)
    .catch(() => {
      return mkdirpAsync(targetFolder);
    });
  }

  _fetch = (file) => {
    return this._runDownload(file)
    .catch(this._catchFSErrors)
    // Passively ignore
    .catch(() => {});
  }

  _fetchAndOpen = (file) => {
    return this._runDownload(file)
    .then((download) => shell.openItem(download.targetPath))
    .catch(this._catchFSErrors)
    .catch((error) => {
      return this._presentError({file, error});
    });
  }

  _saveDownload = (download, savePath) => {
    return new Promise((resolve, reject) => {
      const stream = fs.createReadStream(download.targetPath);
      stream.pipe(fs.createWriteStream(savePath));
      stream.on('error', err => reject(err));
      stream.on('end', () => resolve());
    });
  }

  _fetchAndSave = (file) => {
    const defaultPath = this._defaultSavePath(file);
    const defaultExtension = path.extname(defaultPath);

    NylasEnv.showSaveDialog({defaultPath}, (savePath) => {
      if (!savePath) { return; }

      const saveExtension = path.extname(savePath);
      const newDownloadDirectory = path.dirname(savePath);
      const didLoseExtension = defaultExtension !== '' && saveExtension === '';
      let actualSavePath = savePath
      if (didLoseExtension) {
        actualSavePath += defaultExtension;
      }

      this._runDownload(file)
      .then((download) => this._saveDownload(download, actualSavePath))
      .then(() => {
        if (NylasEnv.savedState.lastDownloadDirectory !== newDownloadDirectory) {
          shell.showItemInFolder(actualSavePath);
          NylasEnv.savedState.lastDownloadDirectory = newDownloadDirectory;
        }
      })
      .catch(this._catchFSErrors)
      .catch(error => {
        this._presentError({file, error});
      });
    });
  }

  _fetchAndSaveAll = (files) => {
    const defaultPath = this._defaultSaveDir();
    const options = {
      defaultPath,
      title: 'Save Into...',
      buttonLabel: 'Download All',
      properties: ['openDirectory', 'createDirectory'],
    };

    return new Promise((resolve) => {
      NylasEnv.showOpenDialog(options, (selected) => {
        if (!selected) { return; }
        const dirPath = selected[0];
        if (!dirPath) { return; }
        NylasEnv.savedState.lastDownloadDirectory = dirPath;

        const lastSavePaths = [];
        const savePromises = files.map((file) => {
          const savePath = path.join(dirPath, file.safeDisplayName());
          return this._runDownload(file)
          .then((download) => this._saveDownload(download, savePath))
          .then(() => lastSavePaths.push(savePath));
        });

        Promise.all(savePromises)
        .then(() => {
          if (lastSavePaths.length > 0) {
            shell.showItemInFolder(lastSavePaths[0]);
          }
          return resolve(lastSavePaths);
        })
        .catch(this._catchFSErrors)
        .catch((error) => {
          return this._presentError({error});
        });
      });
    });
  }

  _abortFetchFile = (file) => {
    const download = this._downloads[file.id];
    if (!download) { return; }
    download.ensureClosed();
    this.trigger();

    const downloadPath = this.pathForFile(file);
    fs.exists(downloadPath, (exists) => {
      if (exists) {
        fs.unlink(downloadPath);
      }
    });
  }

  _defaultSaveDir() {
    let home = ''
    if (process.platform === 'win32') {
      home = process.env.USERPROFILE;
    } else {
      home = process.env.HOME;
    }

    let downloadDir = path.join(home, 'Downloads');
    if (!fs.existsSync(downloadDir)) {
      downloadDir = os.tmpdir();
    }

    if (NylasEnv.savedState.lastDownloadDirectory) {
      if (fs.existsSync(NylasEnv.savedState.lastDownloadDirectory)) {
        downloadDir = NylasEnv.savedState.lastDownloadDirectory;
      }
    }

    return downloadDir;
  }

  _defaultSavePath(file) {
    const downloadDir = this._defaultSaveDir();
    return path.join(downloadDir, file.safeDisplayName());
  }

  _presentError({file, error} = {}) {
    const name = file ? file.displayName() : "one or more files";
    const errorString = error ? error.toString() : "";

    return remote.dialog.showMessageBox({
      type: 'warning',
      message: "Download Failed",
      detail: `Unable to download ${name}. Check your network connection and try again. ${errorString}`,
      buttons: ["OK"],
    });
  }

  _catchFSErrors(error) {
    let message = null;
    if (['EPERM', 'EMFILE', 'EACCES'].includes(error.code)) {
      message = "N1 could not save an attachment. Check that permissions are set correctly and try restarting N1 if the issue persists.";
    }
    if (['ENOSPC'].includes(error.code)) {
      message = "N1 could not save an attachment because you have run out of disk space.";
    }

    if (message) {
      remote.dialog.showMessageBox({
        type: 'warning',
        message: "Download Failed",
        detail: `${message}\n\n${error.message}`,
        buttons: ["OK"],
      });
      return Promise.resolve();
    }
    return Promise.reject(error);
  }
}

export default new FileDownloadStore()
