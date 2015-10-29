pathRelativeToReactNode = function (node, stack) {
  if (!node || !node.parentNode) {
    return stack;
  }
  if (node.dataset && node.dataset.reactid) {
    return stack
  } else {
    index = -1;
    if (node.parentNode && node.parentNode.childNodes) {
      for (var i=0; i < node.parentNode.childNodes.length; i++) {
        if (node.parentNode.childNodes[i] == node) {
          index = i;
        }
      }
      stack.unshift(index)
    }
    return pathRelativeToReactNode(node.parentNode, stack)
  }
}

restoreSelection = function(selectionData) {
  anchorNode = document.querySelector(["[data-reactid='"+selectionData.anchorReactId+"']"]);
  focusNode = document.querySelector(["[data-reactid='"+selectionData.focusReactId+"']"]);
  if (anchorNode && focusNode) {
    for (var i=0; i < selectionData.anchorStack.length; i++) {
      childIndex = selectionData.anchorStack[i]
      if (anchorNode.childNodes) {
        anchorNode = anchorNode.childNodes[childIndex];
      }
    }
    for (var i=0; i < selectionData.focusStack.length; i++) {
      childIndex = selectionData.focusStack[i]
      if (focusNode.childNodes) {
        focusNode = focusNode.childNodes[childIndex]
      }
    }
    selection = document.getSelection();
    console.log("Setting selection", anchorNode, selectionData.anchorOffset, focusNode, selectionData.focusOffset)
    selection.setBaseAndExtent(anchorNode,
                               selectionData.anchorOffset,
                               focusNode,
                               selectionData.focusOffset)
  }
}

getSelectionData = function(){
  selection = document.getSelection();
  selectionData = {
    anchorReactId: null,
    focusReactId: null,
    anchorOffset: selection.anchorOffset,
    focusOffset: selection.focusOffset,
  };
  if (selection.anchorNode) {
    anchorStack = pathRelativeToReactNode(selection.anchorNode, []);
    reactNode = selection.anchorNode;
    for (var i=0; i < anchorStack.length; i++) {
      reactNode = reactNode.parentNode;
    }
    selectionData.anchorReactId = reactNode.dataset.reactid
    selectionData.anchorStack = anchorStack
  }
  if (selection.focusNode) {
    focusStack = pathRelativeToReactNode(selection.focusNode, []);
    reactNode = selection.focusNode;
    for (var i=0; i < focusStack.length; i++) {
      reactNode = reactNode.parentNode;
    }
    selectionData.focusReactId = reactNode.dataset.reactid
    selectionData.focusStack = focusStack
  }
  return selectionData
}

module.exports = {
  restoreSelection: restoreSelection,
  getSelectionData: getSelectionData
};
