import _ from 'underscore';
import path from 'path';
import LessCache from 'less-cache';

// {LessCache} wrapper used by {ThemeManager} to read stylesheets.
export default class LessCompileCache {
  constructor({configDirPath, resourcePath, importPaths}) {
    this.lessSearchPaths = [
      path.join(resourcePath, 'static', 'variables'),
      path.join(resourcePath, 'static'),
    ];

    let allImportPaths = importPaths;
    if (allImportPaths != null) {
      allImportPaths = importPaths.concat(this.lessSearchPaths);
    } else {
      allImportPaths = this.lessSearchPaths;
    }

    this.cache = new LessCache({
      cacheDir: path.join(configDirPath, 'compile-cache', 'less'),
      fallbackDir: path.join(resourcePath, 'less-compile-cache'),
      importPaths: allImportPaths,
      resourcePath: resourcePath,
    });
  }

  // Setting the import paths is a VERY expensive operation (200ms +)
  // because it walks the entire file tree and does a file state for each
  // and every importPath. If we already have the imports, then load it
  // from our backend FileListCache.
  setImportPaths(importPaths = []) {
    const fullImportPaths = importPaths.concat(this.lessSearchPaths);
    if (!_.isEqual(fullImportPaths, this.cache.importPaths)) {
      this.cache.setImportPaths(fullImportPaths);
    }
  }

  read(stylesheetPath) {
    return this.cache.readFileSync(stylesheetPath);
  }

  cssForFile(stylesheetPath, lessContent) {
    return this.cache.cssForFile(stylesheetPath, lessContent);
  }
}
