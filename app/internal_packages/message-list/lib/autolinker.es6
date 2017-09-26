import { RegExpUtils, DOMUtils } from 'mailspring-exports';

function _matchesAnyRegexp(text, regexps) {
  for (const excludeRegexp of regexps) {
    if (excludeRegexp.test(text)) {
      return true;
    }
  }
  return false;
}

function _runOnTextNode(node, matchers) {
  if (node.parentElement) {
    const withinScript = node.parentElement.tagName === 'SCRIPT';
    const withinStyle = node.parentElement.tagName === 'STYLE';
    const withinA = node.parentElement.closest('a') !== null;
    if (withinScript || withinA || withinStyle) {
      return;
    }
  }
  if (node.textContent.trim().length < 4) {
    return;
  }

  let longest = null;
  let longestLength = null;
  for (const [prefix, regex, options = {}] of matchers) {
    regex.lastIndex = 0;
    const match = regex.exec(node.textContent);
    if (match !== null) {
      if (options.exclude && _matchesAnyRegexp(match[0], options.exclude)) {
        continue;
      }
      if (match[0].length > longestLength) {
        longest = [prefix, match];
        longestLength = match[0].length;
      }
    }
  }

  if (longest) {
    const [prefix, match] = longest;
    const href = `${prefix}${match[0]}`;
    const range = document.createRange();
    range.setStart(node, match.index);
    range.setEnd(node, match.index + match[0].length);
    const aTag = DOMUtils.wrap(range, 'A');
    aTag.href = href;
    aTag.title = href;
    return;
  }
}

export function autolink(doc, { async } = {}) {
  // Traverse the new DOM tree and make things that look like links clickable,
  // and ensure anything with an href has a title attribute.
  const textWalker = document.createTreeWalker(doc.body, NodeFilter.SHOW_TEXT);
  const matchers = [
    [
      'mailto:',
      RegExpUtils.emailRegex(),
      {
        // Technically, gmail.com/bengotow@gmail.com is an email address. After
        // matching, manully exclude any email that follows the .*[/?].*@ pattern.
        exclude: [/\..*[/|?].*@/],
      },
    ],
    ['tel:', RegExpUtils.phoneRegex()],
    ['', RegExpUtils.mailspringCommandRegex()],
    ['', RegExpUtils.urlRegex({ matchEntireString: false })],
  ];

  if (async) {
    const fn = deadline => {
      while (textWalker.nextNode()) {
        _runOnTextNode(textWalker.currentNode, matchers);
        if (deadline.timeRemaining() <= 0) {
          window.requestIdleCallback(fn, { timeout: 500 });
          return;
        }
      }
    };
    window.requestIdleCallback(fn, { timeout: 500 });
  } else {
    while (textWalker.nextNode()) {
      _runOnTextNode(textWalker.currentNode, matchers);
    }
  }

  // Traverse the new DOM tree and make sure everything with an href has a title.
  const aTagWalker = document.createTreeWalker(doc.body, NodeFilter.SHOW_ELEMENT, {
    acceptNode: node => (node.href ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_SKIP),
  });
  while (aTagWalker.nextNode()) {
    aTagWalker.currentNode.title = aTagWalker.currentNode.getAttribute('href');
  }
}
