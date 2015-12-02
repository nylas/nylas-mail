import Promise from 'bluebird'

class ContenteditableTestHarness {

  constructor(client, expect) {
    this.expect = expect
    this.client = client;
  }

  init() {
    console.log("INIT TEST HARNESS");
    return this.client.execute(() => {
      ce = document.querySelector(".contenteditable")
      ce.innerHTML = ""
      ce.focus()
    }).then(({value})=>{
      console.log(value);
    })
  }

  expectHTML(expectedHTML) {
    console.log("EXPECTING HTML");
    console.log(expectedHTML);
    return this.client.execute((expect, arg2) => {
      console.log(expect);
      console.log(arg2);
      ce = document.querySelector(".contenteditable")
      expect(ce.innerHTML).toBe(expectedHTML)
      return ce.innerHTML
    }, this.expect, "FOOO").then(({value})=>{
      console.log("GOT HTML VALUE");
      console.log(value);
    }).catch((err)=>{
      console.log("XXXXXXXXXX GOT ERROR")
      console.log(err);
    })
  }

  expectSelection(callback) {
    return this.client.execute(() => {
      ce = document.querySelector(".contenteditable")
      expectSel = callback(ce)

      anchorNode = expectSel.anchorNode || expectSel.node || "No anchorNode found"
      focusNode = expectSel.focusNode || expectSel.node || "No focusNode found"
      anchorOffset = expectSel.anchorOffset || expectSel.offset || 0
      focusOffset = expectSel.focusOffset || expectSel.offset || 0

      selection = document.getSelection()

      this.expect(selection.anchorNode).toBe(anchorNode)
      this.expect(selection.focusNode).toBe(focusNode)
      this.expect(selection.anchorOffset).toBe(anchorOffset)
      this.expect(selection.focusOffset).toBe(focusOffset)
    })
  }
}
module.exports = ContenteditableTestHarness
