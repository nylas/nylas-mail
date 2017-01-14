import {app, protocol} from 'electron';
import fs from 'fs';
import path from 'path';

// Handles requests with 'nylas' protocol.
//
// It's created by {N1Application} upon instantiation and is used to create a
// custom resource loader for 'nylas://' URLs.
//
// The following directories are searched in order:
//   * ~/.nylas-mail/assets
//   * ~/.nylas-mail/dev/packages (unless in safe mode)
//   * ~/.nylas-mail/packages
//   * RESOURCE_PATH/node_modules
//
export default class NylasProtocolHandler {
  constructor(resourcePath, safeMode) {
    this.loadPaths = [];
    this.dotNylasDirectory = path.join(app.getPath('home'), '.nylas-mail');

    if (!safeMode) {
      this.loadPaths.push(path.join(this.dotNylasDirectory, 'dev', 'packages'));
    }

    this.loadPaths.push(path.join(this.dotNylasDirectory, 'packages'));
    this.loadPaths.push(path.join(resourcePath, 'internal_packages'));

    this.registerNylasProtocol();
  }

  // Creates the 'Nylas' custom protocol handler.
  registerNylasProtocol() {
    protocol.registerFileProtocol('nylas', (request, callback) => {
      const relativePath = path.normalize(request.url.substr(7));

      let filePath = null;
      if (relativePath.indexOf('assets/') === 0) {
        const assetsPath = path.join(this.dotNylasDirectory, relativePath);
        const assetsStats = fs.statSyncNoException(assetsPath);
        if (assetsStats.isFile && assetsStats.isFile()) {
          filePath = assetsPath;
        }
      }

      if (!filePath) {
        for (const loadPath of this.loadPaths) {
          filePath = path.join(loadPath, relativePath);
          const fileStats = fs.statSyncNoException(filePath);
          if (fileStats.isFile && fileStats.isFile()) {
            break;
          }
        }
      }

      callback(filePath);
    });
  }
}
