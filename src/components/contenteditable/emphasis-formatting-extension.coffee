{ContenteditableExtension} = require 'nylas-exports'

# This provides the default baisc formatting options for the
# Contenteditable using the declarative extension API.
class EmphasisFormattingExtension extends ContenteditableExtension
  @keyCommandHandlers: =>
    "contenteditable:bold": @_onBold
    "contenteditable:italic": @_onItalic
    "contenteditable:underline": @_onUnderline
    "contenteditable:strikeThrough": @_onStrikeThrough

  @toolbarButtons: => [
    {
      className: "btn-bold"
      onClick: @_onBold
      tooltip: "Bold"
      iconUrl: null # Defined in the css of btn-bold
    }
    {
      className: "btn-italic"
      onClick: @_onItalic
      tooltip: "Italic"
      iconUrl: null # Defined in the css of btn-italic
    }
    {
      className: "btn-underline"
      onClick: @_onUnderline
      tooltip: "Underline"
      iconUrl: null # Defined in the css of btn-underline
    }
  ]

  @_onBold: ({editor, event}) -> editor.bold()

  @_onItalic: ({editor, event}) -> editor.italic()

  @_onUnderline: ({editor, event}) -> editor.underline()

  @_onStrikeThrough: ({editor, event}) -> editor.strikeThrough()

  # None of the emphasis formatting buttons need a custom component.
  #
  # They use the default <ToolbarButtons> component via the
  # `toolbarButtons` extension API.
  #
  # The <ToolbarButtons> core component is managed by the
  # {ToolbarButtonManager}
  @toolbarComponentConfig: => null

module.exports = EmphasisFormattingExtension
