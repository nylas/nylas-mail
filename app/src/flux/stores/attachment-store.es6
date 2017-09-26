import os from 'os';
import fs from 'fs';
import path from 'path';
import { exec } from 'child_process';
import { remote, shell } from 'electron';
import mkdirp from 'mkdirp';
import NylasStore from 'nylas-store';
import DraftStore from './draft-store';
import Actions from '../actions';
import File from '../models/file';
import Utils from '../models/utils';

Promise.promisifyAll(fs);
const mkdirpAsync = Promise.promisify(mkdirp);

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
];

const THUMBNAIL_WIDTH = 320;

class AttachmentStore extends NylasStore {
  constructor() {
    super();

    // viewing messages
    this.listenTo(Actions.fetchFile, this._fetch);
    this.listenTo(Actions.fetchAndOpenFile, this._fetchAndOpen);
    this.listenTo(Actions.fetchAndSaveFile, this._fetchAndSave);
    this.listenTo(Actions.fetchAndSaveAllFiles, this._fetchAndSaveAll);
    this.listenTo(Actions.abortFetchFile, this._abortFetchFile);

    // sending
    this.listenTo(Actions.addAttachment, this._onAddAttachment);
    this.listenTo(Actions.selectAttachment, this._onSelectAttachment);
    this.listenTo(Actions.removeAttachment, this._onRemoveAttachment);

    this._filePreviewPaths = {};
    this._filesDirectory = path.join(NylasEnv.getConfigDirPath(), 'files');
    mkdirp(this._filesDirectory);
  }

  // Returns a path on disk for saving the file. Note that we must account
  // for files that don't have a name and avoid returning <downloads/dir/"">
  // which causes operations to happen on the directory (badness!)
  //
  pathForFile(file) {
    if (!file) {
      return null;
    }
    const id = file.id.toLowerCase();
    return path.join(
      this._filesDirectory,
      id.substr(0, 2),
      id.substr(2, 2),
      id,
      file.safeDisplayName()
    );
  }

  getDownloadDataForFile() {
    // fileId
    // if we ever support downloads again, put this back
    return null;
  }

  // Returns a hash of download objects keyed by fileId
  //
  getDownloadDataForFiles(fileIds = []) {
    const downloadData = {};
    fileIds.forEach(fileId => {
      downloadData[fileId] = this.getDownloadDataForFile(fileId);
    });
    return downloadData;
  }

  previewPathsForFiles(fileIds = []) {
    const previewPaths = {};
    fileIds.forEach(fileId => {
      previewPaths[fileId] = this.previewPathForFile(fileId);
    });
    return previewPaths;
  }

  previewPathForFile(fileId) {
    return this._filePreviewPaths[fileId];
  }

  // Returns a promise with a Download object, allowing other actions to be
  // daisy-chained to the end of the download operation.
  async _ensureFile(file) {
    // If we ever support downloading files individually again, code goes back here!
    this._generatePreview(file);
    return file;
  }

  _generatePreview(file) {
    if (process.platform !== 'darwin') {
      return Promise.resolve();
    }
    if (!NylasEnv.config.get('core.attachments.displayFilePreview')) {
      return Promise.resolve();
    }
    if (NonPreviewableExtensions.includes(file.displayExtension())) {
      return Promise.resolve();
    }

    const filePath = this.pathForFile(file);
    const previewPath = `${filePath}.png`;
    return (
      fs
        .accessAsync(filePath, fs.F_OK)
        .then(() => {
          fs
            .accessAsync(previewPath, fs.F_OK)
            .then(() => {
              // If the preview file already exists, set our state and bail
              this._filePreviewPaths[file.id] = previewPath;
              this.trigger();
            })
            .catch(() => {
              // If the preview file doesn't exist yet, generate it
              const fileDir = `"${path.dirname(filePath)}"`;
              const escapedPath = `"${filePath}"`;
              return new Promise(resolve => {
                const previewSize = THUMBNAIL_WIDTH * (11 / 8.5);
                exec(
                  `qlmanage -t -f ${window.devicePixelRatio} -s ${previewSize} -o ${fileDir} ${escapedPath}`,
                  (error, stdout, stderr) => {
                    if (error) {
                      // Ignore errors, we don't really mind if we can't generate a preview
                      // for a file
                      NylasEnv.reportError(error);
                      resolve();
                      return;
                    }
                    if (stdout.match(/No thumbnail created/i) || stderr) {
                      resolve();
                      return;
                    }
                    this._filePreviewPaths[file.id] = previewPath;
                    this.trigger();
                    resolve();
                  }
                );
              });
            });
        })
        // If the file doesn't exist, ignore the error.
        .catch(() => Promise.resolve())
    );
  }

  // Returns a promise that resolves with true or false. True if the file has
  // been downloaded, false if it should be downloaded.
  //
  async _checkForDownloadedFile(file) {
    try {
      const stats = await fs.statAsync(this.pathForFile(file));
      return stats.size >= file.size;
    } catch (err) {
      return false;
    }
  }

  // Section: Retrieval of Files

  _fetch = file => {
    return (
      this._ensureFile(file)
        .catch(this._catchFSErrors)
        // Passively ignore
        .catch(() => {})
    );
  };

  _fetchAndOpen = file => {
    return this._ensureFile(file)
      .then(() => shell.openItem(this.pathForFile(file)))
      .catch(this._catchFSErrors)
      .catch(error => {
        return this._presentError({ file, error });
      });
  };

  _writeToExternalPath = (file, savePath) => {
    return new Promise((resolve, reject) => {
      const stream = fs.createReadStream(this.pathForFile(file));
      stream.pipe(fs.createWriteStream(savePath));
      stream.on('error', err => reject(err));
      stream.on('end', () => resolve());
    });
  };

  _fetchAndSave = file => {
    const defaultPath = this._defaultSavePath(file);
    const defaultExtension = path.extname(defaultPath);

    NylasEnv.showSaveDialog({ defaultPath }, savePath => {
      if (!savePath) {
        return;
      }

      const saveExtension = path.extname(savePath);
      const newDownloadDirectory = path.dirname(savePath);
      const didLoseExtension = defaultExtension !== '' && saveExtension === '';
      let actualSavePath = savePath;
      if (didLoseExtension) {
        actualSavePath += defaultExtension;
      }

      this._ensureFile(file)
        .then(download => this._writeToExternalPath(download, actualSavePath))
        .then(() => {
          if (NylasEnv.savedState.lastDownloadDirectory !== newDownloadDirectory) {
            shell.showItemInFolder(actualSavePath);
            NylasEnv.savedState.lastDownloadDirectory = newDownloadDirectory;
          }
        })
        .catch(this._catchFSErrors)
        .catch(error => {
          this._presentError({ file, error });
        });
    });
  };

  _fetchAndSaveAll = files => {
    const defaultPath = this._defaultSaveDir();
    const options = {
      defaultPath,
      title: 'Save Into...',
      buttonLabel: 'Download All',
      properties: ['openDirectory', 'createDirectory'],
    };

    return new Promise(resolve => {
      NylasEnv.showOpenDialog(options, selected => {
        if (!selected) {
          return;
        }
        const dirPath = selected[0];
        if (!dirPath) {
          return;
        }
        NylasEnv.savedState.lastDownloadDirectory = dirPath;

        const lastSavePaths = [];
        const savePromises = files.map(file => {
          const savePath = path.join(dirPath, file.safeDisplayName());
          return this._ensureFile(file)
            .then(download => this._writeToExternalPath(download, savePath))
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
          .catch(error => {
            return this._presentError({ error });
          });
      });
    });
  };

  _abortFetchFile = () => {
    // file
    // put this back if we ever support downloading individual files again
    return;
  };

  _defaultSaveDir() {
    let home = '';
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

  _presentError({ file, error } = {}) {
    const name = file ? file.displayName() : 'one or more files';
    const errorString = error ? error.toString() : '';

    return remote.dialog.showMessageBox({
      type: 'warning',
      message: 'Download Failed',
      detail: `Unable to download ${name}. Check your network connection and try again. ${errorString}`,
      buttons: ['OK'],
    });
  }

  _catchFSErrors(error) {
    let message = null;
    if (['EPERM', 'EMFILE', 'EACCES'].includes(error.code)) {
      message =
        'N1 could not save an attachment. Check that permissions are set correctly and try restarting N1 if the issue persists.';
    }
    if (['ENOSPC'].includes(error.code)) {
      message = 'N1 could not save an attachment because you have run out of disk space.';
    }

    if (message) {
      remote.dialog.showMessageBox({
        type: 'warning',
        message: 'Download Failed',
        detail: `${message}\n\n${error.message}`,
        buttons: ['OK'],
      });
      return Promise.resolve();
    }
    return Promise.reject(error);
  }

  // Section: Adding Files

  _assertIdPresent(headerMessageId) {
    if (!headerMessageId) {
      throw new Error('You need to pass the headerID of the message (draft) this Action refers to');
    }
  }

  _getFileStats(filepath) {
    return fs
      .statAsync(filepath)
      .catch(() =>
        Promise.reject(
          new Error(`${filepath} could not be found, or has invalid file permissions.`)
        )
      );
  }

  _copyToInternalPath(originPath, targetPath) {
    return new Promise((resolve, reject) => {
      const readStream = fs.createReadStream(originPath);
      const writeStream = fs.createWriteStream(targetPath);

      readStream.on('error', () => reject(new Error(`Could not read file at path: ${originPath}`)));
      writeStream.on('error', () =>
        reject(new Error(`Could not write ${path.basename(targetPath)} to files directory.`))
      );
      readStream.on('end', () => resolve());
      readStream.pipe(writeStream);
    });
  }

  async _deleteFile(file) {
    try {
      // Delete the file and it's containing folder. Todo: possibly other empty dirs?
      await fs.unlinkAsync(this.pathForFile(file));
      await fs.rmdirAsync(path.dirname(this.pathForFile(file)));
    } catch (err) {
      throw new Error(`Error deleting file file ${file.filename}:\n\n${err.message}`);
    }
  }

  async _applySessionChanges(headerMessageId, changeFunction) {
    const session = await DraftStore.sessionForClientId(headerMessageId);
    const files = changeFunction(session.draft().files);
    session.changes.add({ files });
  }

  // Handlers

  _onSelectAttachment = ({ headerMessageId }) => {
    this._assertIdPresent(headerMessageId);

    // When the dialog closes, it triggers `Actions.addAttachment`
    return NylasEnv.showOpenDialog({ properties: ['openFile', 'multiSelections'] }, paths => {
      if (paths == null) {
        return;
      }
      let pathsToOpen = paths;
      if (typeof pathsToOpen === 'string') {
        pathsToOpen = [pathsToOpen];
      }

      pathsToOpen.forEach(filePath => Actions.addAttachment({ headerMessageId, filePath }));
    });
  };

  _onAddAttachment = async ({
    headerMessageId,
    filePath,
    inline = false,
    onCreated = () => {},
  }) => {
    this._assertIdPresent(headerMessageId);

    try {
      const filename = path.basename(filePath);
      const stats = await this._getFileStats(filePath);
      if (stats.isDirectory()) {
        throw new Error(`${filename} is a directory. Try compressing it and attaching it again.`);
      } else if (stats.size > 15 * 1000000) {
        throw new Error(`${filename} cannot be attached because it is larger than 5MB.`);
      }

      const file = new File({
        id: Utils.generateTempId(),
        filename: filename,
        size: stats.size,
        contentType: null,
        messageId: null,
        contentId: inline ? Utils.generateTempId() : null,
      });

      await mkdirpAsync(path.dirname(this.pathForFile(file)));
      await this._copyToInternalPath(filePath, this.pathForFile(file));

      await this._applySessionChanges(headerMessageId, files => {
        if (files.reduce((c, f) => c + f.size, 0) >= 15 * 1000000) {
          throw new Error(`Can't file more than 15MB of attachments`);
        }
        return files.concat([file]);
      });
      onCreated(file);
    } catch (err) {
      NylasEnv.showErrorDialog(err.message);
    }
  };

  _onRemoveAttachment = async (headerMessageId, fileToRemove) => {
    if (!fileToRemove) {
      return;
    }

    await this._applySessionChanges(headerMessageId, files =>
      files.filter(({ id }) => id !== fileToRemove.id)
    );

    try {
      await this._deleteFile(fileToRemove);
    } catch (err) {
      NylasEnv.showErrorDialog(err.message);
    }
  };
}

export default new AttachmentStore();
