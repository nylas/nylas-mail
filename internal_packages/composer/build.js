{
  baseUrl: "./bower_components",
  paths: {
    "scribe": "scribe/scribe",
    "html-janitor": "html-janitor/html-janitor",
    "scribe-plugin-toolbar": "scribe-plugin-toolbar/scribe-plugin-toolbar",
    "scribe-plugin-sanitizer": "scribe-plugin-sanitizer/scribe-plugin-sanitizer",
    "scribe-plugin-smart-lists": "scribe-plugin-smart-lists/scribe-plugin-smart-lists",
    "scribe-plugin-curly-quotes": "scribe-plugin-curly-quotes/scribe-plugin-curly-quotes",
    "scribe-plugin-blockquote-command": "scribe-plugin-blockquote-command/scribe-plugin-blockquote-command",
    "scribe-plugin-link-prompt-command": "scribe-plugin-link-prompt-command/scribe-plugin-link-prompt-command",
    "scribe-plugin-inline-styles-to-elements": "scribe-plugin-inline-styles-to-elements/scribe-plugin-inline-styles-to-elements",
    "scribe-plugin-intelligent-unlink-command": "scribe-plugin-intelligent-unlink-command/scribe-plugin-intelligent-unlink-command",
    "scribe-plugin-formatter-html-ensure-semantic-elements": "scribe-plugin-formatter-html-ensure-semantic-elements/scribe-plugin-formatter-html-ensure-semantic-elements",
    "scribe-plugin-formatter-plain-text-convert-new-lines-to-html": "scribe-plugin-formatter-plain-text-convert-new-lines-to-html/scribe-plugin-formatter-plain-text-convert-new-lines-to-html"
  },
  name: "almond/almond",
  out: "lib/scribe.js",
  include: [
    "scribe",
    "html-janitor",
    "scribe-plugin-toolbar",
    "scribe-plugin-sanitizer",
    "scribe-plugin-smart-lists",
    "scribe-plugin-curly-quotes",
    "scribe-plugin-blockquote-command",
    "scribe-plugin-link-prompt-command",
    "scribe-plugin-inline-styles-to-elements",
    "scribe-plugin-intelligent-unlink-command",
    "scribe-plugin-formatter-html-ensure-semantic-elements",
    "scribe-plugin-formatter-plain-text-convert-new-lines-to-html"
  ],
  wrap: {
    startFile: 'start.frag',
    endFile: 'end.frag'
  },
  namespace: 'wrap',
  optimize: 'none',
}
