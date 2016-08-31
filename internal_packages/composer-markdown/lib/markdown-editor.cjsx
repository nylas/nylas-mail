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
    @mde.value(Utils.getTextFromHtml(@props.body))

  componentWillReceiveProps: (newProps) =>
    currentText = Utils.getTextFromHtml(@props.body)
    if @props.body isnt newProps.body and currentText.length is 0
      @mde.value(Utils.getTextFromHtml(newProps.body))
      @mde.codemirror.execCommand('goDocEnd')

  focus: =>
    @mde.codemirror.focus()
    @mde.codemirror.execCommand('goDocEnd')

  focusAbsoluteEnd: =>
    @focus()

  getCurrentSelection: ->

  getPreviousSelection: ->

  setSelection: ->

  _onDOMMutated: ->

  _onBodyChanged: =>
    setImmediate =>
      @props.onBodyChanged(target: {value: @mde.value()})

  render: ->
    # TODO sorry
    # Add style tag to disable incompatible plugins
    <div className="markdown-editor">
      <style>
        {".btn-mail-merge { display:none; }"}
        {".btn-emoji { display:none; }"}
        {".btn-templates { display:none; }"}
        {".btn-scheduler { display:none; }"}
        {".btn-translate { display:none; }"}
        {".signature-button-dropdown { display:none; }"}
      </style>
      <textarea
        ref="textarea"
        className="editing-region"
      />
    </div>

module.exports = MarkdownEditor
