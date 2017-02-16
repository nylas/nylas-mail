class ContenteditableTestHarness {

  constructor(client) {
    this.client = client;
  }

  init() {
    return this.client.execute(() => {
      ce = document.querySelector(".contenteditable")
      ce.innerHTML = ""
      ce.focus()
    })
  }

  test({keys, expectedHTML, expectedSelectionResolver}) {
    return this.client.keys(keys).then(()=>{
      return this.expectHTML(expectedHTML)
    }).then(()=>{
      return this.expectSelection(expectedSelectionResolver)
    })
  }

  expectHTML(expectedHTML) {
    return this.client.execute(() => {
      return document.querySelector(".contenteditable").innerHTML
    }).then(({value})=>{
      expect(value).toBe(expectedHTML)
    })
  }

  expectSelection(callback) {
    // Since `execute` fires parameters to Selenium via REST API, we can
    // only pass strings. We serialize the callback so we can run it in
    // the correct execution environment of the window instead of the
    // Selenium wrapper.
    return this.client.execute((callbackStr) => {
      eval(`callback=${callbackStr}`);
      ce = document.querySelector(".contenteditable")
      expectSel = callback(ce)

      anchorNode = expectSel.anchorNode || expectSel.node || "No anchorNode found"
      focusNode = expectSel.focusNode || expectSel.node || "No focusNode found"
      anchorOffset = expectSel.anchorOffset || expectSel.offset || 0
      focusOffset = expectSel.focusOffset || expectSel.offset || 0

      nodeData = (node) => {
        if(node.nodeType === Node.TEXT_NODE) {
          return node.data
        } else {
          return node.outerHTML
        }
      }

      selection = document.getSelection()

      return {
        anchorNodeMatch: selection.anchorNode === anchorNode,
        focusNodeMatch: selection.focusNode === focusNode,
        anchorOffsetMatch: selection.anchorOffset === anchorOffset,
        focusOffsetMatch: selection.focusOffset === focusOffset,
        expectedAnchorNode: nodeData(anchorNode),
        expectedFocusNode: nodeData(focusNode),
        expectedAnchorOffset: anchorOffset,
        expectedFocusOffset: focusOffset,
        actualAnchorNode: nodeData(selection.anchorNode),
        actualFocusNode: nodeData(selection.focusNode),
        actualAnchorOffset: selection.anchorOffset,
        actualFocusOffset: selection.focusOffset,
      }

    }, callback.toString()).then(({value}) => {
      matchInfo = value

      allMatched = true;
      if (!matchInfo.anchorNodeMatch) {
        console.errorColor("\nAnchor nodes don't match")
        console.errorColor(`Expected: "${matchInfo.actualAnchorNode}" to be "${matchInfo.expectedAnchorNode}"`);
        allMatched = false;
      }
      if (!matchInfo.focusNodeMatch) {
        console.errorColor("\nFocus nodes don't match")
        console.errorColor(`Expected: "${matchInfo.actualFocusNode}" to be "${matchInfo.expectedFocusNode}"`);
        allMatched = false;
      }
      if (!matchInfo.anchorOffsetMatch) {
        console.errorColor("\nAnchor offsets don't match")
        console.errorColor(`Expected: ${matchInfo.actualAnchorOffset} to be ${matchInfo.expectedAnchorOffset}`);
        allMatched = false;
      }
      if (!matchInfo.focusOffsetMatch) {
        console.errorColor("\nFocus offsets don't match")
        console.errorColor(`Expected: ${matchInfo.actualFocusOffset} to be ${matchInfo.expectedFocusOffset}`);
        allMatched = false;
      }

      outMsgDescription = "matched. See discrepancies above"
      if (allMatched) { outMsg = outMsgDescription
      } else { outMsg = "Selection" }
      // "Expected Selection to be matched. See discrepancies above"
      expect(outMsg).toBe(outMsgDescription);
    })
  }
}
module.exports = ContenteditableTestHarness
