import {Actions, Utils} from 'nylas-exports';

function safeEncode(str) {
  return btoa(unescape(encodeURIComponent(str)));
}

function safeDecode(str) {
  return atob(decodeURIComponent(escape(str)))
}

function _runOnImageNode(node) {
  if (node.src && node.dataset.nylasFile) {
    node.addEventListener('error', () => {
      const file = JSON.parse(safeDecode(node.dataset.nylasFile), Utils.registeredObjectReviver);
      const initialDisplay = node.style.display;
      const downloadButton = document.createElement('a');
      downloadButton.classList.add('inline-download-prompt')
      downloadButton.textContent = "Click to download inline image";
      downloadButton.addEventListener('click', () => {
        Actions.fetchFile(file);
        node.parentNode.removeChild(downloadButton);
        node.addEventListener('load', () => {
          node.style.display = initialDisplay;
        });
      });
      node.style.display = 'none';
      node.parentNode.insertBefore(downloadButton, node);
    });
  }
}

export function encodedAttributeForFile(file) {
  return safeEncode(JSON.stringify(file, Utils.registeredObjectReplacer));
}

export function addInlineDownloadPrompts(doc) {
  const imgTagWalker = document.createTreeWalker(doc.body, NodeFilter.SHOW_ELEMENT, {
    acceptNode: (node) => {
      if (node.nodeName === 'IMG') {
        return NodeFilter.FILTER_ACCEPT;
      }
      return NodeFilter.FILTER_SKIP;
    },
  });

  while (imgTagWalker.nextNode()) {
    _runOnImageNode(imgTagWalker.currentNode);
  }
}
