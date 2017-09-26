/* eslint global-require: 0 */
import { ipcRenderer } from 'electron';
import crypto from 'crypto';

import RegExpUtils from '../regexp-utils';

let userAgentDefault = null;

class InlineStyleTransformer {
  constructor() {
    this.run = this.run.bind(this);
    this._onInlineStylesResult = this._onInlineStylesResult.bind(this);
    this._inlineStylePromises = {};
    this._inlineStyleResolvers = {};
    ipcRenderer.on('inline-styles-result', this._onInlineStylesResult);
  }

  run(html) {
    if (!html || typeof html !== 'string' || html.length <= 0) {
      return Promise.resolve(html);
    }
    if (!RegExpUtils.looseStyleTag().test(html)) {
      return Promise.resolve(html);
    }

    const key = crypto
      .createHash('md5')
      .update(html)
      .digest('hex');

    // http://stackoverflow.com/questions/8695031/why-is-there-often-a-inside-the-style-tag
    // https://regex101.com/r/bZ5tX4/1
    let styled = html.replace(
      /<style[^>]*>[\n\r \t]*<!--([^</]*)-->[\n\r \t]*<\/style/g,
      (full, content) => `<style>${content}</style`
    );

    styled = this._injectUserAgentStyles(styled);

    if (this._inlineStylePromises[key] == null) {
      this._inlineStylePromises[key] = new Promise(resolve => {
        this._inlineStyleResolvers[key] = resolve;
        ipcRenderer.send('inline-style-parse', { html: styled, key: key });
      });
    }
    return this._inlineStylePromises[key];
  }

  // This will prepend the user agent stylesheet so we can apply it to the
  // styles properly.
  _injectUserAgentStyles(body) {
    // No DOM parsing! Just find the first <style> tag and prepend there.
    const i = body.search(RegExpUtils.looseStyleTag());
    if (i === -1) {
      return body;
    }

    if (typeof userAgentDefault === 'undefined' || userAgentDefault === null) {
      userAgentDefault = require('../chrome-user-agent-stylesheet-string').default;
    }
    return `${body.slice(0, i)}<style>${userAgentDefault}</style>${body.slice(i)}`;
  }

  _onInlineStylesResult(event, { html, key }) {
    delete this._inlineStylePromises[key];
    this._inlineStyleResolvers[key](html);
    delete this._inlineStyleResolvers[key];
  }
}

export default new InlineStyleTransformer();
