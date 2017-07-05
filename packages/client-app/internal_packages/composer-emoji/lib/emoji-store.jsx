/* eslint global-require: "off" */

import NylasStore from 'nylas-store';
import _ from 'underscore';
import EmojiActions from './emoji-actions';

const EmojiJSONKey = 'emoji';

let emojiData;

class EmojiStore extends NylasStore {
  constructor(props) {
    super(props);
    this._emoji = [];
  }

  activate = () => {
    this._emoji = [];
    try {
      const txt = window.localStorage.getItem(EmojiJSONKey);
      if (txt) {
        this._emoji = JSON.parse(txt);
      }
    } catch (err) {
      console.warn('Could not load saved emoji', err);
    }
    this.listenTo(EmojiActions.useEmoji, this._onUseEmoji);
  }

  frequentlyUsedEmoji = () => {
    const sortedEmoji = this._emoji;
    sortedEmoji.sort((a, b) => {
      if (a.frequency < b.frequency) return 1;
      return (b.frequency < a.frequency) ? -1 : 0;
    });
    const sortedEmojiNames = [];
    for (const emoji of sortedEmoji) {
      sortedEmojiNames.push(emoji.emojiName);
    }
    if (sortedEmojiNames.length > 32) {
      return sortedEmojiNames.slice(0, 32);
    }
    return sortedEmojiNames;
  }

  getImagePath(emojiName) {
    emojiData = emojiData || require('./emoji-data').emojiData
    for (const emoji of emojiData) {
      if (emoji.short_names.indexOf(emojiName) !== -1) {
        if (process.platform === "darwin") {
          return `images/composer-emoji/apple/${emoji.image}`;
        }
        return `images/composer-emoji/twitter/${emoji.image}`;
      }
    }
    return ''
  }

  _onUseEmoji = (emoji) => {
    const savedEmoji = _.find(this._emoji, (curEmoji) => {
      return curEmoji.emojiChar === emoji.emojiChar;
    });
    if (savedEmoji) {
      for (const key of Object.keys(emoji)) {
        savedEmoji[key] = emoji[key];
      }
      savedEmoji.frequency++;
    } else {
      _.extend(emoji, {frequency: 1});
      this._emoji.push(emoji);
    }
    this._saveEmoji();
    this.trigger();
  }

  _saveEmoji = () => {
    window.localStorage.setItem(EmojiJSONKey, JSON.stringify(this._emoji));
  }

}

export default new EmojiStore();
