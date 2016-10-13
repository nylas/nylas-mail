import {Actions, Utils} from 'nylas-exports';

function _runOnImageNode(node) {
  if (node.src && node.dataset.nylasFile) {
    node.addEventListener('error', () => {
      const file = JSON.parse(atob(node.dataset.nylasFile), Utils.registeredObjectReviver);
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
  return btoa(JSON.stringify(file, Utils.registeredObjectReplacer));
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
