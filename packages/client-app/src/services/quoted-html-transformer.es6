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
  removeQuotedHTML(html, options = {keepIfWholeBodyIsQuote: true}) {
    const doc = this._parseHTML(html);
    const quoteElements = this._findQuoteLikeElements(doc, options);

    if (options.keepIfWholeBodyIsQuote && this._wholeBodyIsQuote(doc, quoteElements)) {
      return this._outputHTMLFor(this._parseHTML(html), {initialHTML: html});
    }

    DOMUtils.Mutating.removeElements(quoteElements, options);

    // It's possible that the entire body was quoted text anyway and we've
    // removed everything.
    if (options.keepIfWholeBodyIsQuote && (!doc.body || !doc.children[0])) {
      return this._outputHTMLFor(this._parseHTML(html), {initialHTML: html});
    }

    if (!doc.body) {
      return this._outputHTMLFor(this._parseHTML(""), {initialHTML: html});
    }

    this.removeTrailingBr(doc);
    DOMUtils.Mutating.removeElements(quoteStringDetector(doc));
    if (options.keepIfWholeBodyIsQuote && (!doc.children[0] || this._wholeNylasPlaintextBodyIsQuote(doc))) {
      return this._outputHTMLFor(this._parseHTML(html), {initialHTML: html});
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

  _wholeNylasPlaintextBodyIsQuote(doc) {
    const preElement = doc.body.children[0];
    return (preElement && preElement.tagName === 'PRE' && !preElement.children[0]);
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

    /**
     * At this point we've pulled out of the DOM all elements that happen
     * to look like quote blocks via CSS selectors and other patterns.
     * They are not necessarily ordered nor should all be eliminated
     * (because people can type inline around quoted text blocks).
     *
     * The `unwrappedSignatureDetector` looks for a case when signatures
     * look almost exactly like someone replying inline at the end of the
     * message. We detect this case (by looking for signature text
     * repetition) and add it to the set of flagged quote candidates.
     */
    const unwrappedSignatureNodes = unwrappedSignatureDetector(doc, quoteElements)
    quoteElements = quoteElements.concat(unwrappedSignatureNodes)

    if (!includeInline && quoteElements.length > 0) {
      const trailingQuotes = this._findTrailingQuotes(doc, Array.from(quoteElements));

      // Only keep the trailing quotes so we can delete them.
      /**
       * The _findTrailingQuotes method will return an array of the quote
       * elements we should remove. If there was no trailing text, it
       * should include all of the existing VISIBLE quoteElements. If
       * there was trailing text, it will only include the quote elements
       * up to that trailling text. The intersection below will only
       * mark the quote elements below trailing text ot be deleted.
       */
      quoteElements = _.intersection(quoteElements, trailingQuotes);

      /**
       * The _findTraillingQuotes method only preserves VISIBLE elements.
       * It's possible that the unwrappedSignatureDetector discovered a
       * collection of nodes with both visible and not visible (like br)
       * content. If we're going to get rid of trailing signatures we
       * need to also remove those trailling <br/>s, or we can get a bunch
       * of blank space at the end of the text. First make sure that some
       * of our unwrappedSignatureNodes were marked for deletion, and then
       * make sure we include all of them.
       */
      if (_.intersection(quoteElements, unwrappedSignatureNodes).length > 0) {
        quoteElements = _.uniq(quoteElements.concat(unwrappedSignatureNodes))
      }
    }

    return _.compact(_.uniq(quoteElements));
  }

  /**
   * Now that we have a set of quoted text candidates, we need to figure
   * out which ones to remove. The main thing preventing us from removing
   * all of them is the fact users can type text after quoted text as an
   * inline reply.
   *
   * To detect this, we recursively move through the dom backwards, from
   * bottom to top, and keep going until we find visible text that's not a
   * quote candidate. If we find some visible text, we assume that is
   * unique text that a user wrote. We return at that point assuming that
   * everything at the text and above should be visible, even if it's a
   * quoted text candidate.
   *
   * See email_18 and email_23 and unwrapped-signature-detector
   */
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
      if (quoteElements.includes(nodeWithContent)) {
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
    return Array.from(doc.getElementsByClassName(this.annotationClass));
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
    return Array.from(doc.querySelectorAll('.gmail_quote'));
  }

  _findOffice365Quotes(doc) {
    let elements = doc.querySelectorAll('#divRplyFwdMsg, #OLK_SRC_BODY_SECTION');
    elements = Array.from(elements);

    const weirdEl = doc.getElementById('3D"divRplyFwdMsg"');
    if (weirdEl) { elements.push(weirdEl); }

    elements = elements.map((el) => {
      /**
       * When Office 365 wraps quotes in a '#divRplyFwdMsg' id, it usually
       * preceedes it with an <hr> tag and then wraps the entire section
       * in an anonymous div one level up.
       */
      if (el.previousElementSibling && el.previousElementSibling.nodeName === "HR") {
        if (el.parentElement && el.parentElement.nodeName !== "BODY") {
          return el.parentElement;
        }
        const quoteNodes = [el.previousElementSibling, el]
        let node = el.nextSibling;
        while (node) {
          quoteNodes.push(node);
          node = node.nextSibling;
        }
        return quoteNodes
      }
      return el
    });
    return _.flatten(elements);
  }

  _findBlockquoteQuotes(doc) {
    return Array.from(doc.querySelectorAll('blockquote'));
  }
}

export default new QuotedHTMLTransformer();
