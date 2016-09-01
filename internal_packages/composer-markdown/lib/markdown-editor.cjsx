Utils = require './utils'
SimpleMDE = require 'simplemde'
nylas = require 'nylas-exports'
React = nylas.React
ReactDOM = nylas.ReactDOM

# Keep a file-scope variable containing the contents of the markdown stylesheet.
# This will be embedded in the markdown preview iFrame, as well as the email body.
# The stylesheet is loaded when a preview component is first mounted.
markdownStylesheet = null

class MarkdownEditor extends React.Component
  @displayName: 'MarkdownEditor'

  @containerRequired: false

  @contextTypes:
    parentTabGroup: React.PropTypes.object,

  @propTypes:
    body: React.PropTypes.string.isRequired,
    onBodyChanged: React.PropTypes.func.isRequired,

  componentDidMount: =>
    textarea = ReactDOM.findDOMNode(@refs.textarea)
    @mde = new SimpleMDE(
      element: textarea,
      hideIcons: ['fullscreen', 'side-by-side']
      showIcons: ['code', 'table']
    )
    @mde.codemirror.on "change", @_onBodyChanged
    @mde.codemirror.on "keydown", @_onKeyDown
    @mde.value(Utils.getTextFromHtml(@props.body))
    @focus()

  componentWillReceiveProps: (newProps) =>
    currentText = Utils.getTextFromHtml(@props.body)
    if @props.body isnt newProps.body and currentText.length is 0
      @mde.value(Utils.getTextFromHtml(newProps.body))

  focus: =>
    @mde.codemirror.focus()

  focusAbsoluteEnd: =>
    @focus()
    @mde.codemirror.execCommand('goDocEnd')

  getCurrentSelection: ->

  getPreviousSelection: ->

  setSelection: ->

  _onDOMMutated: ->

  _onBodyChanged: =>
    setImmediate =>
      @props.onBodyChanged(target: {value: @mde.value()})

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
      <textarea
        ref="textarea"
        className="editing-region"
      />
    </div>

module.exports = MarkdownEditor
