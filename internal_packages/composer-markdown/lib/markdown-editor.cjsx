Utils = require './utils'
SimpleMDE = require 'simplemde'
{React, ReactDOM, QuotedHTMLTransformer} = require 'nylas-exports'

# Keep a file-scope variable containing the contents of the markdown stylesheet.
# This will be embedded in the markdown preview iFrame, as well as the email body.
# The stylesheet is loaded when a preview component is first mounted.
markdownStylesheet = null

splitContents = (contents) ->
  quoteStart = contents.search(/(<div class="gmail_quote|<signature)/i)
  if quoteStart > 0
    return [contents.substr(0, quoteStart), contents.substr(quoteStart)]
  return [contents, ""]

class MarkdownEditor extends React.Component
  @displayName: 'MarkdownEditor'

  @containerRequired: false

  @contextTypes:
    parentTabGroup: React.PropTypes.object,

  @propTypes:
    body: React.PropTypes.string.isRequired,
    onBodyChanged: React.PropTypes.func.isRequired,

  componentDidMount: =>
    @mde = new SimpleMDE(
      inputStyle: 'contenteditable'
      element: ReactDOM.findDOMNode(@refs.container),
      hideIcons: ['fullscreen', 'side-by-side']
      showIcons: ['code', 'table']
      spellChecker: false,
    )
    @mde.codemirror.on("change", @_onBodyChanged)
    @mde.codemirror.on("keydown", @_onKeyDown)
    @setCurrentBodyInDOM()

  componentDidUpdate: (prevProps) =>
    wasEmpty = prevProps.body.length is 0

    if @props.body isnt prevProps.body and @props.body isnt @currentBodyInDOM()
      @setCurrentBodyInDOM()

    if wasEmpty
      @mde.codemirror.execCommand('goDocEnd')

  focus: =>
    @mde.codemirror.focus()

  focusAbsoluteEnd: =>
    @focus()
    @mde.codemirror.execCommand('goDocEnd')

  setCurrentBodyInDOM: =>
    [editable, uneditable] = splitContents(@props.body)

    uneditableEl = ReactDOM.findDOMNode(@refs.uneditable)
    uneditableEl.innerHTML = uneditable
    uneditableNoticeEl = ReactDOM.findDOMNode(@refs.uneditableNotice)
    if Utils.getTextFromHtml(uneditable).length > 0
      uneditableNoticeEl.style.display = 'block'
    else
      uneditableNoticeEl.style.display = 'none'

    @mde.value(Utils.getTextFromHtml(editable))

  currentBodyInDOM: =>
    uneditableEl = ReactDOM.findDOMNode(@refs.uneditable)
    return @mde.value() + uneditableEl.innerHTML

  getCurrentSelection: ->

  getPreviousSelection: ->

  setSelection: ->
    container = ReactDOM.findDOMNode(@refs.container)
    sel = document.getSelection()
    sel.setBaseAndExtent(container, 0, container, 0)

  _onDOMMutated: ->

  _onBodyChanged: =>
    setImmediate =>
      value = @currentBodyInDOM()
      @props.onBodyChanged({target: {value}})

  _onKeyDown: (codemirror, e)=>
    if e.key is 'Tab' and e.shiftKey is true
      position = codemirror.cursorCoords(true, 'local')
      isAtBeginning = position.top <= 5 and position.left <= 5
      if isAtBeginning
        # TODO i'm /really/ sorry
        # Subject is at position 2 within the tab group, the focused text area
        # in this component is at position 17, so that's why we shift back 15
        # positions.
        # This will break if the dom elements between here and the subject ever
        # change
        @context.parentTabGroup.shiftFocus(-15)
        e.preventDefault()
        e.codemirrorIgnore = true

  render: ->
    # TODO sorry
    # Add style tag to disable incompatible plugins
    <div tabIndex="1" className="markdown-editor" onFocus={@focus}>
      <style>
        {".btn-mail-merge { display:none; }"}
        {".btn-emoji { display:none; }"}
        {".btn-templates { display:none; }"}
        {".btn-scheduler { display:none; }"}
        {".btn-translate { display:none; }"}
      </style>
      <div
        ref="container"
        className="editing-region"
      />
      <div ref="uneditableNotice" style={{display: 'none'}} className="uneditable-notice">
        The markdown editor does not support editing signatures or quoted text. Content below will be included in your message.
      </div>
      <div ref="uneditable"></div>
    </div>

module.exports = MarkdownEditor
