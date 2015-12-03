(function() {
  function rebuildMessages(messageNodes, messages) {
    // Simply insert the message html inside the appropriate node
    for (var idx = 0; idx < messageNodes.length; idx++) {
      var msgNode = messageNodes[idx];
      var msgHtml = messages[idx];
      msgNode.innerHTML = msgHtml;
    }
  }

  function removeClassFromNodes(nodeList, className) {
    for (var idx = 0; idx < nodeList.length; idx++) {
      var node = nodeList[idx];
      var re = new RegExp('\\b' + className + '\\b', 'g');
      node.className = node.className.replace(re, '');
    }
  }

  function removeScrollClasses() {
    var scrollRegions = document.querySelectorAll('.scroll-region');
    var scrollContents = document.querySelectorAll('.scroll-region-content');
    var scrollContentInners = document.querySelectorAll('.scroll-region-content-inner');
    removeClassFromNodes(scrollRegions, 'scroll-region');
    removeClassFromNodes(scrollContents, 'scroll-region-content');
    removeClassFromNodes(scrollContentInners, 'scroll-region-content-inner');
  }

  function print() {
    window.print();
    // Close this print window after selecting to print
    // This is really hackish but appears to be the only working solution
    setTimeout(window.close, 500);
  }

  var messageNodes = document.querySelectorAll('.message-item-area>span');

  removeScrollClasses();
  rebuildMessages(messageNodes, window.printMessages);
  // Give it a few ms before poppint out the print dialog
  setTimeout(print, 50);
})();
