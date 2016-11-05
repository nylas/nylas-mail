import _ from 'underscore';
import DOMUtils from '../dom-utils';
import quoteStringDetector from './quote-string-detector';
import unwrappedSignatureDetector from './unwrapped-signature-detector';

class QuotedHTMLTransformer {

  annotationClass = "nylas-quoted-text-segment";

  // Given an html string, it will add the `annotationClass` to the DOM
  // element
  hideQuotedHTML(html, {keepIfWholeBodyIsQuote} = {}) {
    const doc = this._parseHTML(html);
    const quoteElements = this._findQuoteLikeElements(doc);
    if (!keepIfWholeBodyIsQuote || !this._wholeBodyIsQuote(doc, quoteElements)) {
      this._annotateElements(quoteElements);
    }
    return this._outputHTMLFor(doc, {initialHTML: html});
  }

  hasQuotedHTML(html) {
    const doc = this._parseHTML(html);
    const quoteElements = this._findQuoteLikeElements(doc);
    return quoteElements.length > 0;
  }

  // Public: Removes quoted text from an HTML string
  //
  // If we find a quoted text region that is "inline" with the root level
  // message, meaning it has non quoted text before and after it, then we
  // leave it in the message. If you set the `includeInline` option to true,
  // then all inline blocks will also be removed.
  //
  // - `html` The string full of quoted text areas
  // - `options`
  //   - `includeInline` Defaults false. If true, inline quotes are removed
  //   too
  //   - `keepIfWholeBodyIsQuote` Defaults false. If true, then it will
  //   check to see if the whole html body is a giant quote. If so, it will
  //   preserve it.
  //
  // Returns HTML without quoted text
  removeQuotedHTML(html, options = {}) {
    const doc = this._parseHTML(html);
    const quoteElements = this._findQuoteLikeElements(doc, options);
    if (!options.keepIfWholeBodyIsQuote || !this._wholeBodyIsQuote(doc, quoteElements)) {
      DOMUtils.Mutating.removeElements(quoteElements, options);

      // It's possible that the entire body was quoted text and we've removed everything.
      if (!doc.body) {
        return this._outputHTMLFor(this._parseHTML(""), {initialHTML: html});
      }

      this.removeTrailingBr(doc);
      DOMUtils.Mutating.removeElements(quoteStringDetector(doc));
      if (!doc.children[0]) {
        return this._outputHTMLFor(this._parseHTML(""), {initialHTML: html});
      }
    }

    if (options.returnAsDOM) {
      return doc;
    }
    return this._outputHTMLFor(doc, {initialHTML: html});
  }

  // Finds any trailing BR tags and removes them in place
  removeTrailingBr(doc) {
    const { childNodes } = doc.body;
    const extraTailBrTags = [];
    for (let i = childNodes.length - 1; i >= 0; i--) {
      const curr = childNodes[i];
      const next = childNodes[i - 1];
      if (curr && curr.nodeName === 'BR' && next && next.nodeName === 'BR') {
        extraTailBrTags.push(curr);
      } else {
        break;
      }
    }
    return DOMUtils.Mutating.removeElements(extraTailBrTags);
  }

  appendQuotedHTML(htmlWithoutQuotes, originalHTML) {
    let doc = this._parseHTML(originalHTML);
    const quoteElements = this._findQuoteLikeElements(doc);
    doc = this._parseHTML(htmlWithoutQuotes);
    for (let i = 0; i < quoteElements.length; i++) {
      const node = quoteElements[i];
      doc.body.appendChild(node);
    }
    return this._outputHTMLFor(doc, {initialHTML: originalHTML});
  }

  restoreAnnotatedHTML(html) {
    const doc = this._parseHTML(html);
    const quoteElements = this._findAnnotatedElements(doc);
    this._removeAnnotation(quoteElements);
    return this._outputHTMLFor(doc, {initialHTML: html});
  }

  _parseHTML(text) {
    const domParser = new DOMParser();
    let doc;
    try {
      doc = domParser.parseFromString(text, "text/html");
    } catch (error) {
      const errText = `HTML Parser Error: ${error.toString()}`;
      doc = domParser.parseFromString(errText, "text/html");
      NylasEnv.reportError(error);
    }

    // As far as we can tell, when this succeeds, doc /always/ has at least
    // one child: an <html> node.
    return doc;
  }

  _outputHTMLFor(doc, {initialHTML}) {
    if (/<\s?head\s?>/i.test(initialHTML) || /<\s?body[\s>]/i.test(initialHTML)) {
      return doc.children[0].innerHTML;
    }
    return doc.body.innerHTML;
  }

  _wholeBodyIsQuote(doc, quoteElements) {
    const nonBlankChildElements = [];
    for (let i = 0; i < doc.body.childNodes.length; i++) {
      const child = doc.body.childNodes[i];
      if (child.textContent.trim() === "") {
        continue;
      } else { nonBlankChildElements.push(child); }
    }

    if (nonBlankChildElements.length === 1) {
      return Array.from(quoteElements).includes(nonBlankChildElements[0])
    }
    return false;
  }

    // We used to have a scheme where we cached the `doc` object, keyed by
    // the md5 of the text. Unfortunately we can't do this because the
    // `doc` is mutated in place. Returning clones of the DOM is just as
    // bad as re-parsing from string, which is very fast anyway.

  _findQuoteLikeElements(doc, {includeInline} = {}) {
    const parsers = [
      this._findGmailQuotes,
      this._findOffice365Quotes,
      this._findBlockquoteQuotes,
    ];

    let quoteElements = [];
    for (const parser of parsers) {
      quoteElements = quoteElements.concat(parser(doc) || []);
    }
    quoteElements = quoteElements.concat(unwrappedSignatureDetector(doc, quoteElements))

    if (!includeInline && quoteElements.length > 0) {
      // This means we only want to remove quoted text that shows up at the
      // end of a message. If there were non quoted content after, it'd be
      // inline.

      const trailingQuotes = this._findTrailingQuotes(doc, quoteElements);

      // Only keep the trailing quotes so we can delete them.
      quoteElements = _.intersection(quoteElements, trailingQuotes);
    }

    return _.compact(_.uniq(quoteElements));
  }

  // This will recursievly move through the DOM, bottom to top, and pick
  // out quoted text blocks. It will stop when it reaches a visible
  // non-quote text region.
  _findTrailingQuotes(scopeElement, quoteElements = []) {
    let trailingQuotes = [];

    // We need to find only the child nodes that have content in them. We
    // determine if it's an inline quote based on if there's VISIBLE
    // content after a piece of quoted text
    const nodesWithContent = DOMUtils.nodesWithContent(scopeElement);

    // There may be multiple quote blocks that are sibilings of each
    // other at the end of the message. We want to include all of these
    // trailing quote elements.
    for (let i = nodesWithContent.length - 1; i >= 0; i--) {
      const nodeWithContent = nodesWithContent[i];
      if (Array.from(quoteElements).includes(nodeWithContent)) {
        // This is a valid quote. Let's keep it!
        //
        // This quote block may have many more quote blocks inside of it.
        // Luckily we don't need to explicitly find all of those because
        // one this block gets removed from the DOM, we'll delete all
        // sub-quotes as well.
        trailingQuotes.push(nodeWithContent);
        continue;
      } else {
        const moreTrailing = this._findTrailingQuotes(nodeWithContent, quoteElements);
        trailingQuotes = trailingQuotes.concat(moreTrailing);
        break;
      }
    }

    return trailingQuotes;
  }

  _contains(node, quoteElement) {
    return node === quoteElement || node.contains(quoteElement);
  }

  _findAnnotatedElements(doc) {
    return Array.prototype.slice.call(doc.getElementsByClassName(this.annotationClass));
  }

  _annotateElements(elements = []) {
    let originalDisplay;
    return elements.forEach((el) => {
      el.classList.add(this.annotationClass)
      originalDisplay = el.style.display
      el.style.display = "none"
      el.setAttribute("data-nylas-quoted-text-original-display", originalDisplay);
    });
  }

  _removeAnnotation(elements = []) {
    let originalDisplay;
    return elements.forEach((el) => {
      el.classList.remove(this.annotationClass)
      originalDisplay = el.getAttribute("data-nylas-quoted-text-original-display")
      el.style.display = originalDisplay
      el.removeAttribute("data-nylas-quoted-text-original-display");
    })
  }

  _findGmailQuotes(doc) {
    // Gmail creates both div.gmail_quote and blockquote.gmail_quote. The div
    // version marks text but does not cause indentation, but both should be
    // considered quoted text.
    return Array.prototype.slice.call(doc.querySelectorAll('.gmail_quote'));
  }

  _findOffice365Quotes(doc) {
    let elements = doc.querySelectorAll('#divRplyFwdMsg, #OLK_SRC_BODY_SECTION');
    elements = Array.prototype.slice.call(elements);

    const weirdEl = doc.getElementById('3D"divRplyFwdMsg"');
    if (weirdEl) { elements.push(weirdEl); }

    elements = elements.map((el) => {
      if (el.previousElementSibling && el.previousElementSibling.nodeName === "HR") {
        return el.parentElement;
      }
      return el
    });
    return elements;
  }

  _findBlockquoteQuotes(doc) {
    return Array.prototype.slice.call(doc.querySelectorAll('blockquote'));
  }
}

export default new QuotedHTMLTransformer();
