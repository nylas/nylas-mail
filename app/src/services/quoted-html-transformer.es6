import quoteStringDetector from './quote-string-detector';
import unwrappedSignatureDetector from './unwrapped-signature-detector';
const { FIRST_ORDERED_NODE_TYPE } = XPathResult;

class QuotedHTMLTransformer {
  annotationClass = 'nylas-quoted-text-segment';

  hasQuotedHTML(html) {
    const doc = this._parseHTML(html);
    const quoteElements = this._findQuoteElements(doc);
    return quoteElements.length > 0;
  }

  // Public: Removes quoted text from an HTML string
  //
  // If we find a quoted text region that is "inline" with the root level
  // message, meaning it has non quoted text before and after it, then we
  // leave it in the message.
  //
  // - `html` The string full of quoted text areas
  // - `options`
  //   - `keepIfWholeBodyIsQuote` Defaults false. If true, then it will
  //   check to see if the whole html body is a giant quote. If so, it will
  //   preserve it.
  //
  // Returns HTML without quoted text
  //
  removeQuotedHTML(html, options = { keepIfWholeBodyIsQuote: true }) {
    const doc = this._parseHTML(html);

    for (const el of this._findQuoteElements(doc, options)) {
      el.remove();
    }

    // It's possible that the entire body was quoted text anyway and we've
    // removed everything.
    if (options.keepIfWholeBodyIsQuote) {
      if (!doc.body || !doc.children[0] || doc.body.textContent.trim().length === 0) {
        return this._outputHTMLFor(this._parseHTML(html), { initialHTML: html });
      }
    }

    if (!doc.body) {
      return this._outputHTMLFor(this._parseHTML(''), { initialHTML: html });
    }

    for (const el of quoteStringDetector(doc)) {
      el.remove();
    }

    this._removeImagesStrippedByAnotherClient(doc);
    this._removeUnnecessaryWhitespace(doc);

    return this._outputHTMLFor(doc, { initialHTML: html });
  }

  _removeImagesStrippedByAnotherClient(doc) {
    const result = doc.evaluate(
      "//img[contains(@alt,'removed by sender')]",
      doc.body,
      null,
      XPathResult.ANY_TYPE,
      null
    );
    const nodes = [];

    // collect all the results and then remove them all
    // to avoid modifying the dom while using the xpath selector
    let node = result.iterateNext();
    while (node) {
      nodes.push(node);
      node = result.iterateNext();
    }
    nodes.forEach(n => n.remove());
  }

  _removeUnnecessaryWhitespace(doc) {
    // Find back-to-back <br><br> at the top level and de-duplicate them
    const { children } = doc.body;
    const extraTailBrTags = [];
    for (let i = children.length - 1; i >= 0; i--) {
      const curr = children[i];
      const next = children[i - 1];
      if (curr && curr.nodeName === 'BR' && next && next.nodeName === 'BR') {
        extraTailBrTags.push(curr);
      } else {
        break;
      }
    }
    for (const el of extraTailBrTags) {
      el.remove();
    }

    // Traverse down the tree of "last child" nodes to get the last child of the last child.
    // The deepest node at the end of the document.
    let lastOfLast = doc.body;
    while (lastOfLast.lastElementChild) {
      lastOfLast = lastOfLast.lastElementChild;
    }

    // Traverse back up the tree - at each level, attempt to remove
    // whitespace from the last child and then remove the child itself
    // if it's completely empty. Repeat until a child has meaningful content,
    // then move up the tree.
    //
    // Containers with empty space at the end occur pretty often when we
    // remove the quoted text and it had preceding spaces.
    const removeTrailingWhitespaceChildren = el => {
      while (el.lastChild) {
        const child = el.lastChild;
        if (child.nodeType === Node.TEXT_NODE) {
          if (child.textContent.trim() === '') {
            child.remove();
            continue;
          }
        }
        if (['BR', 'P', 'DIV', 'SPAN', 'HR'].includes(child.nodeName)) {
          removeTrailingWhitespaceChildren(child);
          if (child.childElementCount === 0 && child.textContent.trim() === '') {
            child.remove();
            continue;
          }
        }
        break;
      }
    };

    while (lastOfLast.parentElement) {
      lastOfLast = lastOfLast.parentElement;
      removeTrailingWhitespaceChildren(lastOfLast);
    }
  }

  appendQuotedHTML(htmlWithoutQuotes, originalHTML) {
    let doc = this._parseHTML(originalHTML);
    const quoteElements = this._findQuoteElements(doc);
    doc = this._parseHTML(htmlWithoutQuotes);
    for (let i = 0; i < quoteElements.length; i++) {
      const node = quoteElements[i];
      doc.body.appendChild(node);
    }
    return this._outputHTMLFor(doc, { initialHTML: originalHTML });
  }

  _parseHTML(text) {
    const domParser = new DOMParser();
    let doc;
    try {
      doc = domParser.parseFromString(text, 'text/html');
    } catch (error) {
      const errText = `HTML Parser Error: ${error.toString()}`;
      doc = domParser.parseFromString(errText, 'text/html');
      AppEnv.reportError(error);
    }

    // As far as we can tell, when this succeeds, doc /always/ has at least
    // one child: an <html> node.
    return doc;
  }

  _outputHTMLFor(doc, { initialHTML } = {}) {
    if (/<\s?head\s?>/i.test(initialHTML) || /<\s?body[\s>]/i.test(initialHTML)) {
      return doc.children[0].innerHTML;
    }
    return doc.body.innerHTML;
  }

  _findQuoteElements(doc) {
    const parsers = [
      this._findGmailQuotes,
      this._findBlockquoteQuotes,
      this._findQuotesAfterMessageHeaderBlock,
      this._findConfidentialityNotice,
    ];

    let quoteElements = [];
    for (const parser of parsers) {
      quoteElements = quoteElements.concat(parser(doc) || []);
    }

    // Find top-level nodes that look like a signature - some clients append
    // a signature block /beneath/ the quoted text and we need to count is as
    // quoted text as well — otherwise it gets considered an inline reply block.
    const unwrappedSignatureNodes = unwrappedSignatureDetector(doc, quoteElements);
    quoteElements = quoteElements.concat(unwrappedSignatureNodes);

    // Keep quotes that are followed by non-quote blocks (eg: inline reply text)
    quoteElements = quoteElements.filter(
      el => !this._isElementFollowedByUnquotedElement(el, quoteElements)
    );

    return quoteElements;
  }

  _isElementFollowedByUnquotedElement(el, quoteElements) {
    const seen = [];
    let head = el;

    while (head) {
      // advance to the next sibling, or the parent's next sibling
      while (head && !head.nextSibling) {
        head = head.parentNode;
      }
      if (!head) {
        break;
      }
      head = head.nextSibling;

      // search this branch of the tree for any text nodes / images that
      // are not contained within a matched quoted text block. We mark
      // the subtree as "seen" because we traverse upwards, and would
      // re-evaluate the subtree on each iteration otherwise.
      const pile = [head];
      let node = null;

      // eslint-disable-next-line
      while ((node = pile.pop())) {
        if (seen.includes(node)) {
          continue;
        }
        if (quoteElements.includes(node)) {
          continue;
        }
        if (node.childNodes) {
          pile.push(...node.childNodes);
        }
        if (node.nodeName === 'IMG') {
          return true;
        }
        if (node.nodeType === Node.TEXT_NODE && node.textContent.trim().length > 0) {
          return true;
        }
      }
      seen.push(head);
    }

    return false;
  }

  _findGmailQuotes(doc) {
    // Gmail creates both div.gmail_quote and blockquote.gmail_quote. The div
    // version marks text but does not cause indentation, but both should be
    // considered quoted text.
    return Array.from(doc.querySelectorAll('.gmail_quote'));
  }

  _findBlockquoteQuotes(doc) {
    return Array.from(doc.querySelectorAll('blockquote'));
  }

  _findConfidentialityNotice(doc) {
    // Traverse from the body down the tree of "last" nodes looking for a
    // Confidentiality Notice TEXT_NODE. We need to count this node as quoted
    // text or it'll be handled as an inline reply and totally disable quoted
    // text removal.
    let head = doc.body;
    while (head) {
      const tc = head.textContent.trim();
      if (head.nodeType === Node.TEXT_NODE && tc.startsWith('Confidentiality Notice')) {
        return [head];
      }
      if (head.childNodes.length === 0 && tc === '') {
        head = head.previousSibling;
      } else {
        head = head.lastChild;
      }
    }
    return [];
  }

  _findQuotesAfterMessageHeaderBlock(doc) {
    // This detector looks for a element in the DOM tree containing
    // three children: <b>Sent:</b> or <b>Date:</b> and <b>To:</b> and
    // <b>Subject:</b>. It then returns every node after that as quoted text.

    // Find a DOM node exactly matching <b>Sent:</b>
    const dateXPath = `
      //b[. = 'Sent:'] |
      //b[. = 'Date:'] |
      //span[. = 'Sent: '] |
      //span[. = 'Date: '] |
      //span[. = 'Sent:'] |
      //span[. = 'Date:']`;
    const dateMarker = doc.evaluate(dateXPath, doc.body, null, FIRST_ORDERED_NODE_TYPE, null)
      .singleNodeValue;

    if (dateMarker) {
      // check to see if the parent container also contains the other two
      const headerContainer = dateMarker.parentElement;
      let matches = 0;
      for (const node of Array.from(headerContainer.children)) {
        const tc = node.textContent.trim();
        if (tc === 'To:' || tc === 'Subject:') {
          matches++;
        }
      }
      if (matches === 2) {
        // got a hit! let's cut some text.
        const quotedTextNodes = [];

        // Special case to add "From:" because it's often detatched from the rest of the
        // header fields. We just add it where ever it's located.
        const fromXPath = "//b[. = 'From:'] | //span[. = 'From:']| //span[. = 'From: ']";
        let from = doc.evaluate(fromXPath, doc.body, null, FIRST_ORDERED_NODE_TYPE, null)
          .singleNodeValue;

        if (from) {
          if (from.nodeName === 'SPAN') {
            from = from.parentElement;
          }
          quotedTextNodes.push(from);
        }

        // The headers container and everything past it in the document is quoted text.
        // This traverses the DOM, walking up the tree and adding all siblings below
        // our current path to the array.
        let head = headerContainer;
        while (head) {
          quotedTextNodes.push(head);
          while (head && !head.nextElementSibling) {
            head = head.parentElement;
          }
          if (head) {
            head = head.nextElementSibling;
          }
        }
        return quotedTextNodes;
      }
    }
    return [];
  }
}

export default new QuotedHTMLTransformer();
