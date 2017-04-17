import React from 'react'
import ReactDOMServer from 'react-dom/server'
import ComposerExtension from '../../extensions/composer-extension'
import OverlaidComponents from './overlaid-components'
import CustomContenteditableComponents from './custom-contenteditable-components'

// In this code, "anchor" refers to the "img" tag used in the draft while the
// user is editing it.

// <overlay> is used when the draft is sent.
export default class OverlaidComposerExtension extends ComposerExtension {

  static applyTransformsForSending({draftBodyRootNode, draft}) {
    const overlayImgEls = Array.from(draftBodyRootNode.querySelectorAll('img[data-overlay-id]'));
    for (const imgEl of overlayImgEls) {
      const Component = CustomContenteditableComponents.get(imgEl.dataset.componentKey);
      if (!Component) {
        continue;
      }
      const props = Object.assign({draft, isPreview: true}, JSON.parse(imgEl.dataset.componentProps));
      const reactElement = React.createElement(Component, props);

      const overlayEl = document.createElement('overlay');
      overlayEl.innerHTML = ReactDOMServer.renderToStaticMarkup(reactElement);
      Object.assign(overlayEl.dataset, imgEl.dataset);

      imgEl.parentNode.replaceChild(overlayEl, imgEl);
    }
  }

  static unapplyTransformsForSending({draftBodyRootNode}) {
    const overlayEls = Array.from(draftBodyRootNode.querySelectorAll('overlay[data-overlay-id]'));
    for (const overlayEl of overlayEls) {
      const {componentKey, componentProps, overlayId, style} = overlayEl.dataset;
      const {anchorTag} = OverlaidComponents.buildAnchorTag(componentKey, JSON.parse(componentProps), overlayId, style);
      const anchorFragment = document.createRange().createContextualFragment(anchorTag);
      overlayEl.parentNode.replaceChild(anchorFragment, overlayEl);
    }
  }
}
