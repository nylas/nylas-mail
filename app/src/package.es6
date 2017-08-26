import path from 'path';
import fs from 'fs';

class NoPackageJSONError extends Error {
}

export default class Package {
  static NoPackageJSONError = NoPackageJSONError;

  constructor(dir) {
    this.directory = dir;

    let jsonString = null;
    try {
      jsonString = fs.readFileSync(path.join(dir, 'package.json')).toString();
    } catch (err) {
      // silently fail, not a file
    }
    if (!jsonString) {
      throw new NoPackageJSONError();
    }

    this.json = JSON.parse(jsonString);
    this.name = this.json.name;
    this.displayName = this.json.displayName || this.json.name;
    this.disposables = [];
    this.syncInit = this.json.syncInit;
    this.windowTypes = this.json.windowTypes || {'default': true};
  }

  activate() {
    this.loadKeymaps();
    this.loadMenus();
    this.loadStylesheets();

    if (this.json.main) {
      const root = path.join(this.directory, this.json.main);
      const module = require(root) // eslint-disable-line

      module.activate();

      if (module.config && typeof module.config === 'object') {
        NylasEnv.config.setSchema(this.name, {type: 'object', properties: module.config});
      } else if (module.configDefaults && typeof module.configDefaults === 'object') {
        NylasEnv.config.setDefaults(this.name, module.configDefaults)
      }
      if (module.activateConfig) {
        module.activateConfig();
      }
    }
  }

  deactivate() {
    for (const d of this.disposables) {
      d.dispose();
    }
    this.disposables = [];

    if (this.json.main) {
      const root = path.join(this.directory, this.json.main);
      require(root).deactivate(); // eslint-disable-line
    }
  }

  isTheme() {
    return !!this.json.theme;
  }

  isOptional() {
    return !!this.json.isOptional;
  }

  isDefault() {
    return !!this.json.isDefault;
  }

  getStylesheetsPath() {
    return path.join(this.directory, 'styles');
  }

  loadKeymaps() {
    let keymapPaths = [];
    const keymapsRoot = path.join(this.directory, 'keymaps');
    try {
      keymapPaths = fs.readdirSync(keymapsRoot)
        .filter(fn => fn.endsWith('.json'))
        .map(fn => path.join(keymapsRoot, fn));
    } catch (err) {
      // no menus
    }

    for (const keymapPath of keymapPaths) {
      const content = JSON.parse(fs.readFileSync(keymapPath));
      this.disposables.push(NylasEnv.keymaps.loadKeymap(keymapPath, content));
    }
  }

  loadStylesheets() {
    let stylesheets = [];
    const stylesRoot = this.getStylesheetsPath();
    try {
      const filenames = fs.readdirSync(stylesRoot);
      const index = filenames.find(fn => fn.startsWith('index.'));
      if (index) {
        stylesheets = [path.join(stylesRoot, index)];
      } else {
        stylesheets = filenames
          .filter(fn => fn.endsWith('ss'))
          .map(fn => path.join(stylesRoot, fn))
      }
    } catch (err) {
      // styles directory not found
    }
    for (const sourcePath of stylesheets) {
      const source = NylasEnv.themes.loadStylesheet(sourcePath, true);
      this.disposables.push(NylasEnv.styles.addStyleSheet(source, {sourcePath, priority: 0, context: null}))
    }
  }

  loadMenus() {
    const menusRoot = path.join(this.directory, 'menus');
    let menuPaths = [];

    try {
      menuPaths = fs.readdirSync(menusRoot)
        .filter(fn => fn.endsWith('.json'))
        .map(fn => path.join(menusRoot, fn));
    } catch (err) {
      // no menus
    }

    for (const menuPath of menuPaths) {
      const content = JSON.parse(fs.readFileSync(menuPath));
      if (content.menu) {
        this.disposables.push(NylasEnv.menu.add(content.menu));
      }
    }
  }
}
