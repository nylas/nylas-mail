# Markdown Editor
# Last Revised: April 23, 2015 by Ben Gotow
#
# Markdown editor is a simple React component that allows you to type your
# emails in markdown and see the live preview of your email in html
#
{ExtensionRegistry, ComponentRegistry} = require 'nylas-exports'
MarkdownEditor = require './markdown-editor'
MarkdownComposerExtension = require './markdown-composer-extension'

module.exports =
  activate: ->
    ComponentRegistry.register MarkdownEditor,
      role: 'Composer:Editor'
    ExtensionRegistry.Composer.register(MarkdownComposerExtension)

  serialize: ->

  deactivate: ->
    ComponentRegistry.unregister(MarkdownEditor)
    ExtensionRegistry.Composer.unregister(MarkdownComposerExtension)
