/** @babel */

import webFrame from 'web-frame';

import DictionaryManager from './dictionary-manager';

/**
 * Spellchecking Helper
 * Manages the spellcheckers
 *
 * @class NylasSpellcheck
 */
class NylasSpellcheck {
  constructor() {
    this.spellCheckers = DictionaryManager.createInstancesForInstalledLanguages();

    this.setup();
  }

  setup() {
    const lang = this.getCurrentKeyboardLanguage();
    this.current = this.spellCheckers[lang];

    webFrame.setSpellCheckProvider(lang.replace(/_/, '-'), false, {
      spellCheck: (text) => {
        if (!current) return true;

        let val = !(current.isMisspelled(text));
        return val;
      }
    });
  }

  /**
   * @return if the word provided is misspelled
   */
   isMisspelled(word) {
     if (!this.current) {
       return false;
     }
     return this.current.isMisspelled(word);
   }

   /**
    * @return the corrections for a misspelled word
    */
  getCorrectionsForMisspelling(word) {
    if (!this.current) {
      return [];
    }
    return this.current.getCorrectionsForMisspelling(word);
  }

  /**
   * @private
   * Returns the current keyboard language, or 'en_US' for Linux
   */
  getCurrentKeyboardLanguage() {
    if (process.platform === 'linux') {
      return 'en_US';
    }

    return require('keyboard-layout').getCurrentKeyboardLanguage();
  }
}

export default new NylasSpellcheck();
