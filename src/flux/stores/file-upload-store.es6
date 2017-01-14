import _ from 'underscore';
import fs from 'fs';
import path from 'path';
import rimraf from 'rimraf';
import mkdirp from 'mkdirp';
import NylasStore from 'nylas-store';
import Actions from '../actions';
import Utils from '../models/utils';
import Message from '../models/message';
import DraftStore from './draft-store';
import DatabaseStore from './database-store';

Promise.promisifyAll(fs);
const mkdirpAsync = Promise.promisify(mkdirp);
const UPLOAD_DIR = path.join(NylasEnv.getConfigDirPath(), 'uploads');


class Upload {
  constructor({messageClientId, filePath, stats, id, inline, uploadDir} = {}) {
    this.inline = inline;
    this.stats = stats;
    this.uploadDir = uploadDir || UPLOAD_DIR;
    this.messageClientId = messageClientId;
    this.originPath = filePath;
    this.id = id || Utils.generateTempId();
    this.filename = path.basename(filePath);
    this.targetDir = path.join(this.uploadDir, this.messageClientId, this.id);
    this.targetPath = path.join(this.targetDir, this.filename);
    this.size = this.stats.size;
  }

  get extension() {
    const ext = path.extname(this.filename.toLowerCase())
    return ext.slice(1); // remove leading .
  }
}


class FileUploadStore extends NylasStore {

  Upload = Upload;

  constructor() {
    super()
    this.listenTo(Actions.addAttachment, this._onAddAttachment);
    this.listenTo(Actions.selectAttachment, this._onSelectAttachment);
    this.listenTo(Actions.removeAttachment, this._onRemoveAttachment);
    this.listenTo(DatabaseStore, this._onDataChanged);

    mkdirp.sync(UPLOAD_DIR);
    if (NylasEnv.isMainWindow() || NylasEnv.inSpecMode()) {
      this.listenTo(Actions.ensureMessageInSentSuccess, ({messageClientId}) => {
        this._deleteUploadsForClientId(messageClientId);
      });
    }
  }

  // Helpers

  _assertIdPresent(messageClientId) {
    if (!messageClientId) {
      throw new Error("You need to pass the ID of the message (draft) this Action refers to");
    }
  }

  _getFileStats(filePath) {
    return fs.statAsync(filePath)
    .catch(() => Promise.reject(new Error(`${filePath} could not be found, or has invalid file permissions.`)));
  }

  async _getTotalDirSize(dirpath) {
    const items = await fs.readdirAsync(dirpath)
    let total = 0
    for (const filename of items) {
      const filepath = path.join(dirpath, filename)
      const stats = await this._getFileStats(filepath)
      total += stats.size
    }
    return total
  }

  _copyUpload(upload) {
    return new Promise((resolve, reject) => {
      const {originPath, targetPath} = upload;
      const readStream = fs.createReadStream(originPath);
      const writeStream = fs.createWriteStream(targetPath);

      readStream.on('error', () => reject(new Error(`Could not read file at path: ${originPath}`)));
      writeStream.on('error', () => reject(new Error(`Could not write ${upload.filename} to uploads directory.`)));
      readStream.on('end', () => resolve(upload));
      readStream.pipe(writeStream);
    });
  }

  _deleteUpload(upload) {
    // Delete the upload file
    return fs.unlinkAsync(upload.targetPath).then(() =>
      // Delete the containing folder
      fs.rmdirAsync(upload.targetDir).then(() => {
        // Try to remove the directory for the associated message if this was the
        // last upload
        // Will fail if it's not empty, which is fine.
        fs.rmdir(path.join(UPLOAD_DIR, upload.messageClientId), () => {});
        return Promise.resolve(upload);
      })
    )
    .catch((err) => Promise.reject(new Error(`Error deleting file upload ${upload.filename}:\n\n${err.message}`)));
  }

  _deleteUploadsForClientId(messageClientId) {
    rimraf(path.join(UPLOAD_DIR, messageClientId), {disableGlob: true}, (err) => {
      if (err) {
        console.warn(err);
      }
    });
  }

  _applySessionChanges(messageClientId, changeFunction) {
    return DraftStore.sessionForClientId(messageClientId).then((session) => {
      const uploads = changeFunction(session.draft().uploads);
      session.changes.add({uploads});
    });
  }


  // Handlers

  _onDataChanged = (change) => {
    if (!NylasEnv.isMainWindow()) { return; }
    if (change.objectClass !== Message.name || change.type !== 'unpersist') { return; }

    change.objects.forEach((message) => {
      this._deleteUploadsForClientId(message.clientId);
    });
  }

  _onSelectAttachment = ({messageClientId}) => {
    this._assertIdPresent(messageClientId);

    // When the dialog closes, it triggers `Actions.addAttachment`
    return NylasEnv.showOpenDialog({properties: ['openFile', 'multiSelections']},
      (paths) => {
        if (paths == null) { return; }
        let pathsToOpen = paths
        if (_.isString(pathsToOpen)) {
          pathsToOpen = [pathsToOpen];
        }

        pathsToOpen.forEach((filePath) => Actions.addAttachment({messageClientId, filePath}));
      }
    );
  }

  _onAddAttachment = ({messageClientId, filePath, inline = false, onUploadCreated = (() => {})}) => {
    this._assertIdPresent(messageClientId);

    return this._getFileStats(filePath)
    .then(async (stats) => {
      const upload = new Upload({messageClientId, filePath, stats, inline});
      if (stats.isDirectory()) {
        throw new Error(`${upload.filename} is a directory. Try compressing it and attaching it again.`);
      } else if (stats.size > 15 * 1000000) {
        throw new Error(`${upload.filename} cannot be attached because it is larger than 5MB.`);
      }
      await mkdirpAsync(upload.targetDir)

      const totalSize = await this._getTotalDirSize(upload.targetDir)
      if (totalSize >= 15 * 1000000) {
        throw new Error(`Can't upload more than 15MB of attachments`);
      }

      await this._copyUpload(upload)
      await this._applySessionChanges(upload.messageClientId, (uploads) => uploads.concat([upload]))
      onUploadCreated(upload)
    })
    .catch(this._onAttachFileError);
  }

  _onRemoveAttachment = (uploadToRemove) => {
    if (!uploadToRemove) { return Promise.resolve(); }
    this._applySessionChanges(uploadToRemove.messageClientId, (uploads) => {
      return uploads.filter(({id}) => id !== uploadToRemove.id)
    });
    return this._deleteUpload(uploadToRemove)
    .catch(this._onAttachFileError);
  }

  _onAttachFileError = (error) => {
    NylasEnv.showErrorDialog(error.message);
  }
}

export default new FileUploadStore();
