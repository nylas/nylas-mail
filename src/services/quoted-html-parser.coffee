_ = require 'underscore'

class QuotedHTMLParser

  annotationClass: "nylas-quoted-text-segment"

  # Given an html string, it will add the `annotationClass` to the DOM
  # element
  hideQuotedHTML: (html) ->
    doc = @_parseHTML(html)
    quoteElements = @_findQuoteLikeElements(doc)
    @_annotateElements(quoteElements)
    return doc.children[0].innerHTML

  hasQuotedHTML: (html) ->
    doc = @_parseHTML(html)
    quoteElements = @_findQuoteLikeElements(doc)
    return quoteElements.length > 0

  removeQuotedHTML: (html) ->
    doc = @_parseHTML(html)
    quoteElements = @_findQuoteLikeElements(doc)
    @_removeQuoteElements(quoteElements)
    return doc.children[0].innerHTML

  restoreAnnotatedHTML: (html) ->
    doc = @_parseHTML(html)
    quoteElements = @_findAnnotatedElements(doc)
    @_removeAnnotation(quoteElements)
    return doc.children[0].innerHTML

  _parseHTML: (text) ->
    # The `DOMParser` is VERY fast. Some benchmarks on MacBook Pro 2.3GHz
    # i7:
    #
    # On an 1k email it took 0.13ms
    # On an 88k real-world large-email it takes ~4ms
    # On a million-character wikipedia page on Barack Obama it takes ~30ms
    domParser = new DOMParser()
    doc = domParser.parseFromString(text, "text/html")

  _findQuoteLikeElements: (doc) ->
    parsers = [
      @_findGmailQuotes
      @_findOffice365Quotes
      @_findBlockquoteQuotes
    ]

    quoteElements = []
    for parser in parsers
      quoteElements = quoteElements.concat(parser(doc) ? [])
    return _.compact(_.uniq(quoteElements))

  _findAnnotatedElements: (doc) ->
    Array::slice.call(doc.getElementsByClassName(@annotationClass))

  _annotateElements: (elements=[]) ->
    for el in elements
      el.classList.add(@annotationClass)
      originalDisplay = el.style.display
      el.style.display = "none"
      el.setAttribute("data-nylas-quoted-text-original-display", originalDisplay)

  _removeAnnotation: (elements=[]) ->
    for el in elements
      el.classList.remove(@annotationClass)
      originalDisplay = el.getAttribute("data-nylas-quoted-text-original-display")
      el.style.display = originalDisplay
      el.removeAttribute("data-nylas-quoted-text-original-display")

  _removeQuoteElements: (elements=[]) ->
    for el in elements
      try
        if el.parentNode then el.parentNode.removeChild(el)
      catch
        # This can happen if we've already removed ourselves from the node
        # or it no longer exists
        continue

  _findGmailQuotes: (doc) ->
    # There can sometimes be `div.gmail_quote` that are false positives.
    return Array::slice.call(doc.querySelectorAll('blockquote.gmail_quote'))

  _findOffice365Quotes: (doc) ->
    elements = doc.querySelectorAll('#divRplyFwdMsg, #OLK_SRC_BODY_SECTION')
    elements = Array::slice.call(elements)

    weirdEl = doc.getElementById('3D"divRplyFwdMsg"')
    if weirdEl then elements.push(weirdEl)

    elements = _.map elements, (el) ->
      if el.previousElementSibling.nodeName is "HR"
        return el.parentElement
      else return el
    return elements

  _findBlockquoteQuotes: (doc) ->
    return Array::slice.call(doc.querySelectorAll('blockquote'))


module.exports = new QuotedHTMLParser
