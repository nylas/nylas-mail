import { remote } from 'electron';
import fs from 'fs';
import path from 'path';

const MenuItem = remote.MenuItem;
const customDictFilePath = path.join(AppEnv.getConfigDirPath(), 'custom-dict.json');

class Spellchecker {
  constructor() {
    this.isMisspelledCache = {};
    this.handler = null;

    this._customDictLoaded = false;
    this._saveOnLoad = false;
    this._savingCustomDict = false;
    this._saveAgain = false;

    this._customDict = {};

    // Nobody will notice if spellcheck isn't avaialable for a few seconds and it
    // takes a considerable amount of time to startup (212ms in dev mode on my 2017 MBP)
    const initHandler = () => {
      const { SpellCheckHandler } = require('electron-spellchecker'); //eslint-disable-line
      this.handler = new SpellCheckHandler();
      this.handler.switchLanguage('en-US'); // Start with US English
      this.handler.attachToInput();
      this._loadCustomDict();
    };

    if (AppEnv.inSpecMode()) {
      initHandler();
    } else {
      setTimeout(initHandler, 5000);
    }
  }

  _loadCustomDict = () => {
    fs.readFile(customDictFilePath, (err, data) => {
      let fileData = data;
      if (err) {
        if (err.code === 'ENOENT') {
          // File doesn't exist, we haven't saved any words yet
          fileData = '{}';
        } else {
          AppEnv.reportError(err);
          return;
        }
      }
      const loadedDict = JSON.parse(fileData);
      this._customDict = Object.assign(loadedDict, this._customDict);
      this._customDictLoaded = true;
      if (this._saveOnLoad) {
        this._saveCustomDict();
        this._saveOnLoad = false;
      }
    });
  };

  _saveCustomDict = () => {
    // If we haven't loaded the dict yet, saving could overwrite all the things.
    // Wait until the loaded dict is merged with our working copy before saving
    if (this._customDictLoaded) {
      // Don't perform two writes at the same time, as this results in an overlaid
      // version of the data. (This may or may not happen in practice, but was
      // an issue with the tests)
      if (this._savingCustomDict) {
        this._saveAgain = true;
      } else {
        this._savingCustomDict = true;
        fs.writeFile(customDictFilePath, JSON.stringify(this._customDict), err => {
          if (err) {
            AppEnv.reportError(err);
          }
          this._savingCustomDict = false;
          if (this._saveAgain) {
            this._saveAgain = false;
            this._saveCustomDict();
          }
        });
      }
    } else {
      this._saveOnLoad = true;
    }
  };

  isMisspelled = word => {
    if (!this.handler) {
      return false;
    }
    if ({}.hasOwnProperty.call(this._customDict, word)) {
      return false;
    }
    if ({}.hasOwnProperty.call(this.isMisspelledCache, word)) {
      return this.isMisspelledCache[word];
    }
    const misspelled = !this.handler.handleElectronSpellCheck(word);
    this.isMisspelledCache[word] = misspelled;
    return misspelled;
  };

  learnWord = word => {
    this._customDict[word] = '';
    this._saveCustomDict();
  };

  unlearnWord = word => {
    if (word in this._customDict) {
      delete this._customDict[word];
      this._saveCustomDict();
    }
  };

  appendSpellingItemsToMenu = ({ menu, word, onCorrect, onDidLearn }) => {
    if (this.isMisspelled(word)) {
      const corrections = this.handler.currentSpellchecker.getCorrectionsForMisspelling(word);
      if (corrections.length > 0) {
        corrections.forEach(correction => {
          menu.append(
            new MenuItem({
              label: correction,
              click: () => onCorrect(correction),
            })
          );
        });
      } else {
        menu.append(new MenuItem({ label: 'No Guesses Found', enabled: false }));
      }
      menu.append(new MenuItem({ type: 'separator' }));

      menu.append(
        new MenuItem({
          label: 'Learn Spelling',
          click: () => {
            this.learnWord(word);
            if (onDidLearn) {
              onDidLearn(word);
            }
          },
        })
      );
      menu.append(new MenuItem({ type: 'separator' }));
    }
  };
}

export default new Spellchecker();
