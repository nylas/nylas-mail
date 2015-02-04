module.exports = function () {
  return function (scribe) {
    /**
     * If the paragraphs option is set to true, we unapply the blockquote on
     * <enter> keypresses if the caret is on a new line.
     */

    scribe.el.addEventListener('mouseup', function (event) {
      var codeNodes = scribe.el.getElementsByTagName('code');
      scribe.transactionManager.run(function () {

        var selection = new scribe.api.Selection();
        var range = selection.range;

        for (var i = 0; i < codeNodes.length; i++) {
          var codeNode = codeNodes[i];

          if ((selection.selection.focusNode.parentNode == codeNode) &&
              (codeNode.classList.contains("empty"))) {
            range.selectNode(codeNode);
            selection.selection.removeAllRanges();
            selection.selection.addRange(range);
            event.preventDefault();
            break;
          }
        }
      });
    });

    scribe.el.addEventListener('input', function (event) {
      var codeNodes = scribe.el.getElementsByTagName('code');

      scribe.transactionManager.run(function () {
        var selection = new scribe.api.Selection();
        for (var i = 0; i < codeNodes.length; i++) {
          if (selection.selection.focusNode.parentNode == codeNodes[i]) {
            codeNodes[i].classList.remove("empty");
            break;
          }
        };
      });
    });


    scribe.el.addEventListener('keydown', function (event) {
      if (event.keyCode === 9) { // tab
        var codeNodes = scribe.el.getElementsByTagName('code');

        scribe.transactionManager.run(function () {
          var selection = new scribe.api.Selection();
          var range = selection.range;

          var jumpOptionNodes = [];
          for (var i = 0; i < codeNodes.length; i++) {
            if ((selection.selection.focusNode.parentNode === codeNodes[i]) ||
                (!codeNodes[i].classList.contains("empty"))) {
              continue;
            }
            jumpOptionNodes.push(codeNodes[i]);
          }

          var found = function(codeNode) {
            range.selectNode(codeNode);
            selection.selection.removeAllRanges();
            selection.selection.addRange(range);
            event.preventDefault();
            event.stopPropagation();
          };

          if (!event.shiftKey) {
            for (var i = 0; i < jumpOptionNodes.length; i++) {
              if (range.comparePoint(jumpOptionNodes[i],1) === 1) {
                found(jumpOptionNodes[i]);
                break;
              }
            }

          } else {
            for (var i = jumpOptionNodes.length-1; i >= 0; i--) {
              var codeNode = jumpOptionNodes[i];
              if (range.comparePoint(jumpOptionNodes[i],1) === -1) {
                found(jumpOptionNodes[i]);
                break;
              }
            }
          }

        });
      };
    });
  };
};
