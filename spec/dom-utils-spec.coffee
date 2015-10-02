_ = require 'underscore'
DOMUtils = require '../src/dom-utils'
describe 'nodesWithContent', ->

  tests = {
    "": null

    "<br>": null

    "<div><br><br/><p></p></div>": null

    """
      <br id="1">
      <img>
      <br id="2">
    """: "<img>"

    """
      Hello
    """: "Hello"

    """
      <div>Hello</div>
    """: "<div>Hello</div>"

    """
      <div>Hello</div>
      Foobar
    """: "Foobar"

    """
      <br>
      <span>Hello</span>
      <br>
    """: "<span>Hello</span>"

    """
      <br>
      <span id="a">Hello</span>
      <br>
      <span id="b">World</span>
      <br>

      <br>
    """: """<span id="b">World</span>"""

    """
      <div>Hello</div>
      <div>
        <p></p>
        <span></span>
      </div>
    """: "<div>Hello</div>"

    """
      <div>Hello</div>
      <div style="display:none">
        I'm hidden
      </div>
    """: "<div>Hello</div>"

    """
      <div>Hello</div>
      <div style="opacity:0">
        I'm hidden
      </div>
    """: "<div>Hello</div>"
  }

  it "tests nodesWithContent", ->
    for input, output of tests
      nodes = DOMUtils.nodesWithContent(input)
      node = _.last(nodes) ? null
      if node
        tmp = document.createElement('div')
        tmp.appendChild(node)
        expect(tmp.innerHTML.trim()).toEqual output
      else
        expect(node).toEqual output
