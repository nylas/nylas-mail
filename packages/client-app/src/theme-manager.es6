import {Emitter} from 'event-kit';
import path from 'path';
import fs from 'fs-plus';

const CONFIG_THEME_KEY = 'core.theme';

export default class ThemeManager {
  constructor({packageManager, resourcePath, configDirPath, safeMode}) {
    this.packageManager = packageManager;
    this.resourcePath = resourcePath;
    this.configDirPath = configDirPath;
    this.safeMode = safeMode;

    this.emitter = new Emitter();
    this.styleSheetDisposablesBySourcePath = {};
    this.lessCache = null;

    this.setBodyClasses();
    NylasEnv.config.onDidChange(CONFIG_THEME_KEY, () => {
      this.setBodyClasses();
      if (this.lessCache) {
        this.lessCache.setImportPaths(this.getImportPaths());
      }
      // reload all stylesheets attached to the dom
      for (const styleEl of Array.from(document.head.querySelectorAll('[source-path]'))) {
        if (styleEl.sourcePath.endsWith('.less')) {
          styleEl.textContent = this.loadStylesheet(styleEl.sourcePath, true);
        }
      }
      this.emitter.emit('did-change-active-themes');
    });
  }

  watchCoreStyles() {
    console.log('Watching /static and /internal_packages for LESS changes')
    const watchStylesIn = (folder) => {
      const stylePaths = fs.listTreeSync(folder);
      const PathWatcher = require('pathwatcher'); //eslint-disable-line
      stylePaths.forEach((stylePath) => {
        if (!stylePath.endsWith('.less')) {
          return;
        }
        PathWatcher.watch(stylePath, () => {
          const styleEl = document.head.querySelector(`[source-path="${stylePath}"]`);
          styleEl.textContent = this.loadStylesheet(styleEl.sourcePath, true);
        });
      });
    };
    watchStylesIn(`${this.resourcePath}/static`);
    watchStylesIn(`${this.resourcePath}/internal_packages`);
  }

  // Essential: Invoke `callback` when style sheet changes associated with
  // updating the list of active themes have completed.
  //
  // * `callback` {Function}
  //
  onDidChangeActiveThemes(callback) {
    return this.emitter.on('did-change-active-themes', callback);
  }

  getBaseTheme() {
    return this.packageManager.getPackageNamed('ui-light');
  }

  getActiveTheme() {
    return this.packageManager.getPackageNamed(NylasEnv.config.get(CONFIG_THEME_KEY)) || this.getBaseTheme();
  }

  getAvailableThemes() {
    return this.packageManager.getAvailablePacakges().filter(p => p.isTheme());
  }

  // Set the active theme.
  //  * `packageName` {string} - the theme package to activate
  //
  setActiveTheme(packageName) {
    NylasEnv.config.set(CONFIG_THEME_KEY, packageName);
    // because we're observing the config, changes will be applied
  }

  setBodyClasses() {
    for (const cls of Array.from(document.body.classList)) {
      if (cls.startsWith('theme-')) {
        document.body.classList.remove(cls);
      }
    }
    document.body.classList.add(`theme-${this.getBaseTheme().name}`);
    document.body.classList.add(`theme-${this.getActiveTheme().name}`);
  }

  getImportPaths() {
    const paths = [this.getBaseTheme().getStylesheetsPath()];
    const active = this.getActiveTheme();
    if (active) {
      paths.unshift(active.getStylesheetsPath());
    }
    return paths;
  }

  // Section: Private
  // ------

  requireStylesheet(stylesheetPath) {
    const sourcePath = this.resolveStylesheet(stylesheetPath);
    if (!sourcePath) {
      throw new Error("Could not find a file at path '#{stylesheetPath}'")
    }
    const content = this.loadStylesheet(sourcePath);
    this.styleSheetDisposablesBySourcePath[sourcePath] = NylasEnv.styles.addStyleSheet(content, {sourcePath})
  }

  loadBaseStylesheets() {
    this.requireStylesheet('../static/index');
    this.requireStylesheet('../static/email-frame');
  }

  resolveStylesheet(stylesheetPath) {
    console.log(stylesheetPath);
    if (path.extname(stylesheetPath).length > 0) {
      return fs.resolveOnLoadPath(stylesheetPath);
    }
    return fs.resolveOnLoadPath(stylesheetPath, ['css', 'less']);
  }

  loadStylesheet(stylesheetPath, importFallbackVariables) {
    if (path.extname(stylesheetPath) === '.less') {
      return this.loadLessStylesheet(stylesheetPath, importFallbackVariables);
    }
    return fs.readFileSync(stylesheetPath, 'utf8');
  }

  loadLessStylesheet(lessStylesheetPath, importFallbackVariables = false) {
    if (!this.lessCache) {
      const LessCompileCache = require('./less-compile-cache').default; //eslint-disable-line
      this.lessCache = new LessCompileCache({
        configDirPath: this.configDirPath,
        resourcePath: this.resourcePath,
        importPaths: this.getImportPaths(),
      });
    }

    try {
      let less = fs.readFileSync(lessStylesheetPath, 'utf8').toString();
      if (importFallbackVariables) {
        less = `@import "variables/ui-variables";\n\n${less}`;
      }
      return this.lessCache.cssForFile(lessStylesheetPath, less);
    } catch (error) {
      let message = `Error loading Less stylesheet: ${lessStylesheetPath}`;
      let detail = error.message;

      if (error.line !== undefined) {
        message = `Error compiling Less stylesheet: ${lessStylesheetPath}`;
        detail = `
          Line number: ${error.line}
          ${error.message}
        `;
      }
      console.error(message, {detail, dismissable: true});
      console.error(detail);
      throw error;
    }
  }
}
