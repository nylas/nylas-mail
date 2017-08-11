import {DOMUtils} from 'nylas-exports';

// A saved out selection object
//
// When exporting a selection we need to be sure to deeply `cloneNode`.
// This is because sometimes our anchorNodes are divs with nested <br>
// tags. If we don't do a deep clone then when `isEqualNode` is run it will
// erroneously return false.
//
class ExportedSelection {
  constructor(rawSelection, scopeNode) {
    this.rawSelection = rawSelection;
    this.scopeNode = scopeNode;
    this.type = this.rawSelection.type;

    if (this.type !== 'None') {
      this.anchorNode = this.rawSelection.anchorNode.cloneNode(true);
      this.anchorOffset = this.rawSelection.anchorOffset;
      this.anchorNodeIndex = DOMUtils.getNodeIndex(this.scopeNode, this.rawSelection.anchorNode);
      this.focusNode = this.rawSelection.focusNode.cloneNode(true);
      this.focusOffset = this.rawSelection.focusOffset;
      this.focusNodeIndex = DOMUtils.getNodeIndex(this.scopeNode, this.rawSelection.focusNode);
    }
    this.isCollapsed = this.rawSelection.isCollapsed;
  }

  /* Public: Tests for equality amongst exported selections

  When we restore the selection later, we need to find a node that looks
  the same as the one we saved (since they're different object
  references).

  Unfortunately there many be many nodes that "look" the same (match the
  `isEqualNode`) test. For example, say I have a bunch of lines with the
  TEXT_NODE "Foo". All of those will match `isEqualNode`. To fix this we
  assume there will be multiple matches and keep track of the index of the
  match. e.g. all "Foo" TEXT_NODEs may look alike, but I know I want the
  Nth "Foo" TEXT_NODE. We store this information in the `startNodeIndex`
  and `endNodeIndex` fields via the `DOMUtils.getNodeIndex` method.
  */
  isEqual(otherSelection) {
    if (!otherSelection) {
      return false;
    }
    if (this.type !== otherSelection.type) {
      return false;
    }

    if (this.type === 'None' && otherSelection.type === 'None') {
      return true;
    }
    if ((otherSelection.anchorNode == null) || (otherSelection.focusNode == null)) {
      return false;
    }

    const anchorIndex = DOMUtils.getNodeIndex(this.scopeNode, otherSelection.anchorNode);
    const focusIndex = DOMUtils.getNodeIndex(this.scopeNode, otherSelection.focusNode);

    let anchorEqual = otherSelection.anchorNode.isEqualNode(this.anchorNode);
    let anchorIndexEqual = anchorIndex === this.anchorNodeIndex;
    let focusEqual = otherSelection.focusNode.isEqualNode(this.focusNode);
    let focusIndexEqual = focusIndex === this.focusNodeIndex;
    if (!anchorEqual && !focusEqual) {
      // This means the otherSelection is the same, but just from the opposite
      // direction. We don't care in this case, so check the reciprocal as
      // well.
      anchorEqual = otherSelection.anchorNode.isEqualNode(this.focusNode);
      anchorIndexEqual = anchorIndex === this.focusNodeIndex;
      focusEqual = otherSelection.focusNode.isEqualNode(this.anchorNode);
      focusIndexEqual = focusIndex === this.anchorndNodeIndex;
    }

    let anchorOffsetEqual = otherSelection.anchorOffset === this.anchorOffset;
    let focusOffsetEqual = otherSelection.focusOffset === this.focusOffset;
    if (!anchorOffsetEqual && !focusOffsetEqual) {
      // This means the otherSelection is the same, but just from the opposite
      // direction. We don't care in this case, so check the reciprocal as
      // well.
      anchorOffsetEqual = otherSelection.anchorOffset === this.focusOffset;
      focusOffsetEqual = otherSelection.focusOffset === this.anchorOffset;
    }

    return (anchorEqual && anchorIndexEqual && anchorOffsetEqual &&
      focusEqual && focusIndexEqual && focusOffsetEqual);
  }
}

export default ExportedSelection;
