  return {
    HtmlJanitor: wrap.require('html-janitor'),
    Scribe: wrap.require('scribe'),
    ScribePluginToolbar: wrap.require("scribe-plugin-toolbar"),
    ScribePluginSanitizer: wrap.require("scribe-plugin-sanitizer"),
    ScribePluginSmartLists: wrap.require("scribe-plugin-smart-lists"),
    ScribePluginCurlyQuotes: wrap.require("scribe-plugin-curly-quotes"),
    ScribePluginBlockquoteCommand: wrap.require("scribe-plugin-blockquote-command"),
    ScribePluginLinkPromptCommand: wrap.require("scribe-plugin-link-prompt-command"),
    ScribePluginInlineStylesToElements: wrap.require("scribe-plugin-inline-styles-to-elements"),
    ScribePluginIntelligentUnlinkCommand: wrap.require("scribe-plugin-intelligent-unlink-command"),
    ScribePluginFormatterHtmlEnsureSemanticElements: wrap.require("scribe-plugin-formatter-html-ensure-semantic-elements"),
    ScribePluginFormatterPlainTextConvertNewLinesToHtml: wrap.require("scribe-plugin-formatter-plain-text-convert-new-lines-to-html")
  };
})();
