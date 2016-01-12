{DOMUtils} = require 'nylas-exports'

# A saved out selection object
#
# When exporting a selection we need to be sure to deeply `cloneNode`.
# This is because sometimes our anchorNodes are divs with nested <br>
# tags. If we don't do a deep clone then when `isEqualNode` is run it will
# erroneously return false.
#
class ExportedSelection
  constructor: (@rawSelection, @scopeNode) ->
    @type = @rawSelection.type

    unless @type is 'None'
      @anchorNode = @rawSelection.anchorNode.cloneNode(true)
      @anchorOffset = @rawSelection.anchorOffset
      @anchorNodeIndex = DOMUtils.getNodeIndex(@scopeNode, @rawSelection.anchorNode)
      @focusNode = @rawSelection.focusNode.cloneNode(true)
      @focusOffset = @rawSelection.focusOffset
      @focusNodeIndex = DOMUtils.getNodeIndex(@scopeNode, @rawSelection.focusNode)
    @isCollapsed = @rawSelection.isCollapsed

  ### Public: Tests for equality amongst exported selections

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
  ###
  isEqual: (otherSelection) ->
    return false unless otherSelection?
    return false if @type isnt otherSelection.type

    return true if @type is 'None' and otherSelection.type is 'None'
    return false if not otherSelection.anchorNode? or not otherSelection.focusNode?

    anchorIndex = DOMUtils.getNodeIndex(@scopeNode, otherSelection.anchorNode)
    focusIndex = DOMUtils.getNodeIndex(@scopeNode, otherSelection.focusNode)

    anchorEqual = otherSelection.anchorNode.isEqualNode @anchorNode
    anchorIndexEqual = anchorIndex is @anchorNodeIndex
    focusEqual = otherSelection.focusNode.isEqualNode @focusNode
    focusIndexEqual = focusIndex is @focusNodeIndex
    if not anchorEqual and not focusEqual
      # This means the otherSelection is the same, but just from the opposite
      # direction. We don't care in this case, so check the reciprocal as
      # well.
      anchorEqual = otherSelection.anchorNode.isEqualNode @focusNode
      anchorIndexEqual = anchorIndex is @focusNodeIndex
      focusEqual = otherSelection.focusNode.isEqualNode @anchorNode
      focusIndexEqual = focusIndex is @anchorndNodeIndex

    anchorOffsetEqual = otherSelection.anchorOffset == @anchorOffset
    focusOffsetEqual = otherSelection.focusOffset == @focusOffset
    if not anchorOffsetEqual and not focusOffsetEqual
      # This means the otherSelection is the same, but just from the opposite
      # direction. We don't care in this case, so check the reciprocal as
      # well.
      anchorOffsetEqual = otherSelection.anchorOffset == @focusOffset
      focusOffsetEqual = otherSelection.focusOffset == @anchorOffset

    if (anchorEqual and
        anchorIndexEqual and
        anchorOffsetEqual and
        focusEqual and
        focusIndexEqual and
        focusOffsetEqual)
      return true
    else
      return false

module.exports = ExportedSelection
