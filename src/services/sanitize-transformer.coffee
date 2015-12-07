sanitizeHtml = require 'sanitize-html'

Preset =
  Strict:
    allowedTags: ['p', 'b', 'i', 'em', 'strong', 'a', 'br', 'img', 'ul', 'ol', 'li', 'strike', 'table']
    allowedAttributes:
      a: ['href', 'name']
      img: ['src', 'alt']
    transformTags:
      h1: "p"
      h2: "p"
      h3: "p"
      h4: "p"
      h5: "p"
      h6: "p"
      div: "p"
      pre: "p"
      blockquote: "p"

  Permissive:
    allowedTags: ['p', 'b', 'i', 'em', 'strong', 'a', 'br', 'img', 'ul', 'ol', 'li', 'strike', 'table', 'tr', 'td', 'th', 'col', 'colgroup']
    allowedAttributes: [ 'abbr', 'accept', 'acceptcharset', 'accesskey', 'action', 'align', 'alt', 'async', 'autocomplete', 'axis', 'border', 'bgcolor', 'cellpadding', 'cellspacing', 'char', 'charoff', 'charset', 'checked', 'classid', 'classname', 'colspan', 'cols', 'content', 'contextmenu', 'controls', 'coords', 'data', 'datetime', 'defer', 'dir', 'disabled', 'download', 'draggable', 'enctype', 'form', 'formaction', 'formenctype', 'formmethod', 'formnovalidate', 'formtarget', 'frame', 'frameborder', 'headers', 'height', 'hidden', 'high', 'href', 'hreflang', 'htmlfor', 'httpequiv', 'icon', 'id', 'label', 'lang', 'list', 'loop', 'low', 'manifest', 'marginheight', 'marginwidth', 'max', 'maxlength', 'media', 'mediagroup', 'method', 'min', 'multiple', 'muted', 'name', 'novalidate', 'nowrap', 'open', 'optimum', 'pattern', 'placeholder', 'poster', 'preload', 'radiogroup', 'readonly', 'rel', 'required', 'role', 'rowspan', 'rows', 'rules', 'sandbox', 'scope', 'scoped', 'scrolling', 'seamless', 'selected', 'shape', 'size', 'sizes', 'sortable', 'sorted', 'span', 'spellcheck', 'src', 'srcdoc', 'srcset', 'start', 'step', 'style', 'summary', 'tabindex', 'target', 'title', 'translate', 'type', 'usemap', 'valign', 'value', 'width', 'wmode' ]

  UnsafeOnly:
    allowedTags: ["a", "abbr", "address", "area", "article", "aside", "audio", "b", "bdi", "bdo", "big", "blockquote", "body", "br", "button", "canvas", "caption", "cite", "code", "col", "colgroup", "data", "datalist", "dd", "del", "details", "dfn", "dialog", "div", "dl", "dt", "em", "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hr", "i", "img", "input", "ins", "kbd", "keygen", "label", "legend", "li", "main", "map", "mark", "menu", "menuitem", "meta", "meter", "nav", "object", "ol", "optgroup", "option", "output", "p", "param", "picture", "pre", "progress", "q", "rp", "rt", "ruby", "s", "samp", "section", "select", "small", "source", "span", "strong", "sub", "summary", "sup", "table", "tbody", "td", "textarea", "tfoot", "th", "thead", "time", "title", "tr", "track", "u", "ul", "var", "video", "wbr"]
    allowedAttributes: [ 'abbr', 'accept', 'acceptcharset', 'accesskey', 'action', 'align', 'alt', 'async', 'autocomplete', 'axis', 'border', 'bgcolor', 'cellpadding', 'cellspacing', 'char', 'charoff', 'charset', 'checked', 'classid', 'classname', 'colspan', 'cols', 'content', 'contextmenu', 'controls', 'coords', 'data', 'datetime', 'defer', 'dir', 'disabled', 'download', 'draggable', 'enctype', 'form', 'formaction', 'formenctype', 'formmethod', 'formnovalidate', 'formtarget', 'frame', 'frameborder', 'headers', 'height', 'hidden', 'high', 'href', 'hreflang', 'htmlfor', 'httpequiv', 'icon', 'id', 'label', 'lang', 'list', 'loop', 'low', 'manifest', 'marginheight', 'marginwidth', 'max', 'maxlength', 'media', 'mediagroup', 'method', 'min', 'multiple', 'muted', 'name', 'novalidate', 'nowrap', 'open', 'optimum', 'pattern', 'placeholder', 'poster', 'preload', 'radiogroup', 'readonly', 'rel', 'required', 'role', 'rowspan', 'rows', 'rules', 'sandbox', 'scope', 'scoped', 'scrolling', 'seamless', 'selected', 'shape', 'size', 'sizes', 'sortable', 'sorted', 'span', 'spellcheck', 'src', 'srcdoc', 'srcset', 'start', 'step', 'style', 'summary', 'tabindex', 'target', 'title', 'translate', 'type', 'usemap', 'valign', 'value', 'width', 'wmode' ]
    allowedSchemes: [ 'http', 'https', 'ftp', 'mailto', 'data' ]


class SanitizeTransformer
  Preset: Preset

  run: (body, settings = Preset.Strict) ->
    if settings.allowedAttributes instanceof Array
      attrMap = {}
      for tag in settings.allowedTags
        attrMap[tag] = settings.allowedAttributes
      settings.allowedAttributes = attrMap

    return Promise.resolve(sanitizeHtml(body, settings))

module.exports = new SanitizeTransformer()
