import fs from 'fs';
import path from 'path';

import Task from './task';
import {APIError} from '../errors';
import File from '../models/file';
import NylasAPI from '../nylas-api';
import NylasAPIRequest from '../nylas-api-request';
import BaseDraftTask from './base-draft-task';
import DatabaseStore from '../stores/database-store';
import MultiRequestProgressMonitor from '../../multi-request-progress-monitor';

export default class SyncbackDraftFilesTask extends BaseDraftTask {

  constructor(draftClientId) {
    super(draftClientId);
    this._appliedUploads = null;
    this._appliedFiles = null;
  }

  label() {
    return "Uploading attachments...";
  }

  performRemote() {
    return this.refreshDraftReference()
    .then(this.uploadAttachments)
    .then(this.applyChangesToDraft)
    .thenReturn(Task.Status.Success)
    .catch((err) => {
      if (err instanceof BaseDraftTask.DraftNotFoundError) {
        return Promise.resolve(Task.Status.Continue);
      }
      if (err instanceof APIError && !NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
        return Promise.resolve(Task.Status.Retry);
      }
      return Promise.resolve([Task.Status.Failed, err]);
    });
  }

  uploadAttachments = () => {
    this._attachmentUploadsMonitor = new MultiRequestProgressMonitor();
    Object.defineProperty(this, 'progress', {
      configurable: true,
      enumerable: true,
      get: () => this._attachmentUploadsMonitor.value(),
    });

    this._appliedUploads = [];
    this._removedUploads = [];

    this.draft.uploads.forEach((u) => {
      if (u.inline && !this.draft.body.includes(`cid:${u.id}`)) {
        this._removedUploads.push(u);
      } else {
        this._appliedUploads.push(u);
      }
    });

    return Promise.all(this._appliedUploads.map(this.uploadAttachment)).then((files) => {
      // Note: We don't actually delete uploaded files until send completes,
      // because it's possible for the app to quit without saving state and
      // need to re-upload the file.
      this._appliedFiles = files;
    });
  }

  uploadAttachment = (upload) => {
    const {targetPath, size} = upload;

    const formData = {
      file: { // Must be named `file` as per the Nylas API spec
        value: fs.createReadStream(targetPath),
        options: {
          filename: path.basename(targetPath),
        },
      },
    }

    return new NylasAPIRequest({
      api: NylasAPI,
      options: {
        path: "/files",
        accountId: this.draft.accountId,
        method: "POST",
        json: false,
        formData,
        started: (req) =>
          this._attachmentUploadsMonitor.add(targetPath, size, req),
        timeout: 20 * 60 * 1000,
      },
    })
    .run()
    .finally(() => {
      this._attachmentUploadsMonitor.remove(targetPath);
    })
    .then((rawResponseString) => {
      const json = JSON.parse(rawResponseString);
      const file = (new File()).fromJSON(json[0]);
      return Promise.resolve(file);
    })
  }

  applyChangesToDraft = () => {
    return DatabaseStore.inTransaction((t) => {
      return this.refreshDraftReference().then(() => {
        if (!(this.draft.uploads instanceof Array)) {
          this.draft.uploads = [];
        }

        // replace uploads with files
        this._appliedFiles.forEach((file, idx) => {
          const upload = this._appliedUploads[idx];

          // update the draft object
          this.draft.files.push(file);
          this.draft.uploads = this.draft.uploads.filter(u =>
            u.targetPath !== upload.targetPath
          );
          // replace references in the body
          this.draft.body = this.draft.body.replace(`cid:${upload.id}`, `cid:${file.id}`);
        });

        // remove "stale" inline uploads that are no longer present in the body,
        // could have been cut out or deleted during text editing.
        this._removedUploads.forEach((upload) => {
          this.draft.uploads = this.draft.uploads.filter(u =>
            u.targetPath !== upload.targetPath
          );
        });

        return t.persistModel(this.draft);
      });
    });
  }
}
