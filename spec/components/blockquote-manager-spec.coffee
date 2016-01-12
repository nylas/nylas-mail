{DOMUtils} = require 'nylas-exports'
BlockquoteManager = require '../../src/components/contenteditable/blockquote-manager'

describe "BlockquoteManager", ->
  outdentCases = ["""
  <div>|</div>
  """
  ,
  """
  <div>
    <span>|</span>
  </div>
  """
  ,
  """
  <p></p>
  <span>\n</span>
  <span>|</span>
  """
  ,
  """
  <span></span>
  <p></p>
  <span></span>
  <span>|</span>
  """
  ,
  """
  <div>
    <div>
      <div>|</div>
    </div>
  </div>
  """
  ,
  """
  <div>
    <span></span>
    <span>|</span>
  </div>
  """
  ,
  """
  <span></span>
  <p><span>yo</span></p>
  <span></span>
  <span>
    <span></span>
    <span></span>
    <span>|test</span>
  </span>
  """
  ]

  backspaceCases = ["""
  <div>yo|</div>
  """
  ,
  """
  <div>
    yo
    <span>|</span>
  </div>
  """
  ,
  """
  <p></p>
  <span>&nbsp;</span>
  <span>|</span>
  """
  ,
  """
  <span></span>
  <p></p>
  <span>yo</span>
  <span>|</span>
  """
  ,
  """
  <div>
    <div>
      <div>yo|</div>
    </div>
  </div>
  """
  ,
  """
  <div>
    <span>yo</span>
    <span>|</span>
  </div>
  """
  ,
  """
  <span></span>
  <p><span>yo</span></p>
  <span></span>
  <span>
    <span>yo</span>
    <span></span>
    <span>|test</span>
  </span>
  """
  ]

  setupContext = (testCase) ->
    context = document.createElement("blockquote")
    context.innerHTML = testCase
    {node, index} = DOMUtils.findCharacter(context, "|")
    if not node then throw new Error("Couldn't find where to set Selection")
    mockSelection = {
      isCollapsed: true
      anchorNode: node
      anchorOffset: index
    }
    return mockSelection

  outdentCases.forEach (testCase) ->
    it """outdents\n#{testCase}""", ->
      mockSelection = setupContext(testCase)
      editor = {currentSelection: -> mockSelection}
      expect(BlockquoteManager._isInBlockquote(editor)).toBe true
      expect(BlockquoteManager._isAtStartOfLine(editor)).toBe true

  backspaceCases.forEach (testCase) ->
    it """backspaces (does NOT outdent)\n#{testCase}""", ->
      mockSelection = setupContext(testCase)
      editor = {currentSelection: -> mockSelection}
      expect(BlockquoteManager._isInBlockquote(editor)).toBe true
      expect(BlockquoteManager._isAtStartOfLine(editor)).toBe false
