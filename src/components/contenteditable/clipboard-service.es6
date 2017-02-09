/* eslint global-require: 0 */
import {
  InlineStyleTransformer,
  SanitizeTransformer,
  RegExpUtils,
  Utils,
} from 'nylas-exports';

import ContenteditableService from './contenteditable-service';

export default class ClipboardService extends ContenteditableService {
  constructor(...args) {
    super(...args);
    this.onFilePaste = this.props.onFilePaste;
  }

  setData(...args) {
    super.setData(...args);
    this.onFilePaste = this.props.onFilePaste;
  }

  eventHandlers() {
    return {
      onPaste: this.onPaste,
    };
  }

  onPaste = (event) => {
    if (event.clipboardData.items.length === 0) {
      return;
    }
    event.preventDefault();

    // If the pasteboard has a file on it, stream it to a teporary
    // file and fire our `onFilePaste` event.
    const item = event.clipboardData.items[0];

    if (item.kind === 'file') {
      const temp = require('temp');
      const path = require('path');
      const fs = require('fs');
      const blob = item.getAsFile();
      const ext = {
        'image/png': '.png',
        'image/jpg': '.jpg',
        'image/tiff': '.tiff',
      }[item.type] || '';

      const reader = new FileReader();
      reader.addEventListener('loadend', () => {
        const buffer = new Buffer(new Uint8Array(reader.result));
        const tmpFolder = temp.path('-nylas-attachment');
        const tmpPath = path.join(tmpFolder, `Pasted File${ext}`);
        fs.mkdir(tmpFolder, () => {
          fs.writeFile(tmpPath, buffer, () => {
            if (this.onFilePaste) {
              this.onFilePaste(tmpPath);
            }
          });
        });
      });
      reader.readAsArrayBuffer(blob);
    } else {
      const {input, mimetype} = this._getBestRepresentation(event.clipboardData);

      if (mimetype === 'text/plain') {
        const encoded = Utils.encodeHTMLEntities(input);
        const htmlified = encoded.replace(/[\r\n]|&#1[03];/g, "<br/>").replace(/\s\s/g, " &nbsp;");
        document.execCommand("insertHTML", false, htmlified);
      } else if (mimetype === 'text/html') {
        this._sanitizeHTMLInput(input).then(cleanHtml => document.execCommand("insertHTML", false, cleanHtml));
      } else {
        // Do nothing. No appropriate format is available
      }
    }
  }

  _getBestRepresentation(clipboardData) {
    for (const mimetype of ["text/html", "text/plain"]) {
      const data = clipboardData.getData(mimetype) || "";
      if (data.length > 0) {
        return {input: data, mimetype};
      }
    }

    return {input: null, mimetype: null};
  }

  // This is used when pasting text in
  _sanitizeHTMLInput(rawInput) {
    // Check if we are pasting any of our tracked links
    const withoutTracking = rawInput.replace(RegExpUtils.trackedLinkRegex(), (match, p1) =>
      decodeURIComponent(p1)
    );

    return InlineStyleTransformer.run(withoutTracking)
    .then((inlined) => {
      return SanitizeTransformer.run(inlined, SanitizeTransformer.Preset.Permissive)
      .then((sanitized) => {
        return Promise.resolve(
          sanitized
          // We never want more then 2 line breaks in a row.
          // https://regex101.com/r/gF6bF4/4
          .replace(/(<br\s*\/?>\s*){3,}/g, "<br/><br/>")

          // We never want to keep leading and trailing <brs>, since the user
          // would have started a new paragraph themselves if they wanted space
          // before what they paste.
          // BAD:    "<p>begins at<br>12AM</p>" => "<br><br>begins at<br>12AM<br><br>"
          // Better: "<p>begins at<br>12AM</p>" => "begins at<br>12"
          .replace(/^(<br ?\/>)+/, '')
          .replace(/(<br ?\/>)+$/, '')
        );
      });
    });
  }
}
