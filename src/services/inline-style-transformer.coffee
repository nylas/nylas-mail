{ipcRenderer} = require "electron"
RegExpUtils = require '../regexp-utils'
crypto = require 'crypto'
_ = require 'underscore'

class InlineStyleTransformer
  constructor: ->
    @_inlineStylePromises = {}
    @_inlineStyleResolvers = {}
    ipcRenderer.on 'inline-styles-result', @_onInlineStylesResult

  run: (html) =>
    return Promise.resolve(html) unless html and _.isString(html) and html.length > 0
    return Promise.resolve(html) unless RegExpUtils.looseStyleTag().test(html)

    key = crypto.createHash('md5').update(html).digest('hex')

    # http://stackoverflow.com/questions/8695031/why-is-there-often-a-inside-the-style-tag
    # https://regex101.com/r/bZ5tX4/1
    html = html.replace /<style[^>]*>[\n\r]*<!--([^<\/]*)-->[\n\r]*<\/style/g, (full, content) ->
      "<style>#{content}</style"

    html = @_injectUserAgentStyles(html)

    @_inlineStylePromises[key] ?= new Promise (resolve, reject) =>
      @_inlineStyleResolvers[key] = resolve
      ipcRenderer.send('inline-style-parse', {html, key})
    return @_inlineStylePromises[key]

  # This will prepend the user agent stylesheet so we can apply it to the
  # styles properly.
  _injectUserAgentStyles: (body) ->
    # No DOM parsing! Just find the first <style> tag and prepend there.
    i = body.search(RegExpUtils.looseStyleTag())
    return body if i is -1

    userAgentDefault = require '../chrome-user-agent-stylesheet-string'
    return "#{body[0...i]}<style>#{userAgentDefault}</style>#{body[i..-1]}"

  _onInlineStylesResult: (event, {html, key}) =>
    delete @_inlineStylePromises[key]
    @_inlineStyleResolvers[key](html)
    delete @_inlineStyleResolvers[key]
    return

module.exports = new InlineStyleTransformer()
