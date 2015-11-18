
xdescribe "ListManager", ->
  beforeEach ->
    @ce = new ContenteditableTestHarness

  it "Creates ordered lists", ->
    @ce.type ['1', '.', ' ']
    @ce.expectHTML "<ol><li></li></ol>"
    @ce.expectSelection (dom) ->
      dom.querySelectorAll("li")[0]

  it "Undoes ordered list creation with backspace", ->
    @ce.type ['1', '.', ' ', 'backspace']
    @ce.expectHTML "1.&nbsp;"
    @ce.expectSelection (dom) ->
      node: dom.childNodes[0]
      offset: 3

  it "Creates unordered lists with star", ->
    @ce.type ['*', ' ']
    @ce.expectHTML "<ul><li></li></ul>"
    @ce.expectSelection (dom) ->
      dom.querySelectorAll("li")[0]

  it "Undoes unordered list creation with backspace", ->
    @ce.type ['*', ' ', 'backspace']
    @ce.expectHTML "*&nbsp;"
    @ce.expectSelection (dom) ->
      node: dom.childNodes[0]
      offset: 2

  it "Creates unordered lists with dash", ->
    @ce.type ['-', ' ']
    @ce.expectHTML "<ul><li></li></ul>"
    @ce.expectSelection (dom) ->
      dom.querySelectorAll("li")[0]

  it "Undoes unordered list creation with backspace", ->
    @ce.type ['-', ' ', 'backspace']
    @ce.expectHTML "-&nbsp;"
    @ce.expectSelection (dom) ->
      node: dom.childNodes[0]
      offset: 2

  it "create a single item then delete it with backspace", ->
    @ce.type ['-', ' ', 'a', 'left', 'backspace']
    @ce.expectHTML "a"
    @ce.expectSelection (dom) ->
      node: dom.childNodes[0]
      offset: 0

  it "create a single item then delete it with tab", ->
    @ce.type ['-', ' ', 'a', 'shift-tab']
    @ce.expectHTML "a"
    @ce.expectSelection (dom) -> dom.childNodes[0]
      node: dom.childNodes[0]
      offset: 1

  describe "when creating two items in a list", ->
    beforeEach ->
      @twoItemKeys = ['-', ' ', 'a', 'enter', 'b']

    it "creates two items with enter at end", ->
      @ce.type @twoItemKeys
      @ce.expectHTML "<ul><li>a</li><li>b</li></ul>"
      @ce.expectSelection (dom) ->
        node: dom.querySelectorAll('li')[1].childNodes[0]
        offset: 1

    it "backspace from the start of the 1st item outdents", ->
      @ce.type @twoItemKeys.concat ['left', 'up', 'backspace']

    it "backspace from the start of the 2nd item outdents", ->
      @ce.type @twoItemKeys.concat ['left', 'backspace']

    it "shift-tab from the start of the 1st item outdents", ->
      @ce.type @twoItemKeys.concat ['left', 'up', 'shift-tab']

    it "shift-tab from the start of the 2nd item outdents", ->
      @ce.type @twoItemKeys.concat ['left', 'shift-tab']

    it "shift-tab from the end of the 1st item outdents", ->
      @ce.type @twoItemKeys.concat ['up', 'shift-tab']

    it "shift-tab from the end of the 2nd item outdents", ->
      @ce.type @twoItemKeys.concat ['shift-tab']

    it "backspace from the end of the 1st item doesn't outdent", ->
      @ce.type @twoItemKeys.concat ['up', 'backspace']

    it "backspace from the end of the 2nd item doesn't outdent", ->
      @ce.type @twoItemKeys.concat ['backspace']

  describe "multi-depth bullets", ->
    it "creates multi level bullet when tabbed in", ->
      @ce.type ['-', ' ', 'a', 'tab']

    it "creates multi level bullet when tabbed in", ->
      @ce.type ['-', ' ', 'tab', 'a']

    it "returns to single level bullet on backspace", ->
      @ce.type ['-', ' ', 'a', 'tab', 'left', 'backspace']

    it "returns to single level bullet on shift-tab", ->
      @ce.type ['-', ' ', 'a', 'tab', 'shift-tab']
