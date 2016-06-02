import React from 'react'
import ReactDOMServer from 'react-dom/server'
import ComposerExtension from '../../extensions/composer-extension'
// import {ANCHOR_CLASS, IMG_SRC} from './anchor-constants'
import OverlaidComponents from './overlaid-components'
import CustomContenteditableComponents from './custom-contenteditable-components'

export default class OverlaidComposerExtension extends ComposerExtension {

  // https://regex101.com/r/fW6sV3/2
  static _serializedExtractRe() {
    return /<overlay .*?data-overlay-id="(.*?)" data-component-props="(.*?)" data-component-key="(.*?)" data-style="(.*?)".*?>.*?<\/overlay>/gmi
  }

  static _serializedReplacerRe(id) {
    return new RegExp(`<overlay .*?data-overlay-id="${id}".*?>.*?<\/overlay>`, 'gim')
  }

  // https://regex101.com/r/rK3uA3/1
  static _anchorExtractRe() {
    return /<img .*?data-overlay-id="(.*?)" data-component-props="(.*?)" data-component-key="(.*?)" style="(.*?)".*?>/gmi
  }

  static _anchorReplacerRe(id) {
    return new RegExp(`<img .*?data-overlay-id="${id}".*?>`, 'gim')
  }

  static *overlayMatches(re, body) {
    let result = re.exec(body);
    while (result) {
      let props = result[2];
      props = JSON.parse(props.replace(/&quot;/g, `"`));
      const data = {
        dataOverlayId: result[1],
        dataComponentProps: props,
        dataComponentKey: result[3],
        dataStyle: result[4],
      }
      yield data
      result = re.exec(body);
    }
    return
  }

  static applyTransformsToDraft({draft}) {
    const self = OverlaidComposerExtension;
    const outDraft = draft.clone();
    let outBody = outDraft.body;
    const matcher = self.overlayMatches(self._anchorExtractRe(), outDraft.body)

    for (const match of matcher) {
      const componentData = CustomContenteditableComponents.get(match.dataComponentKey);
      if (!componentData || !componentData.serialized) {
        continue
      }
      const component = componentData.serialized
      const props = Object.assign({draft}, match.dataComponentProps);
      const el = React.createElement(component, props);
      let html = ReactDOMServer.renderToStaticMarkup(el);

      html = `<overlay data-overlay-id="${match.dataOverlayId}" data-component-props="${OverlaidComponents.propsToDOMAttr(match.dataComponentProps)}" data-component-key="${match.dataComponentKey}" data-style="${match.dataStyle}">${html}</overlay>`

      outBody = outBody.replace(OverlaidComposerExtension._anchorReplacerRe(match.dataOverlayId), html)
    }

    outDraft.body = outBody;
    return outDraft;
  }

  static unapplyTransformsToDraft({draft}) {
    const self = OverlaidComposerExtension;
    const outDraft = draft.clone();
    let outBody = outDraft.body

    const matcher = self.overlayMatches(self._serializedExtractRe(), outDraft.body);

    for (const match of matcher) {
      const {anchorTag} = OverlaidComponents.buildAnchorTag(match.dataComponentKey, match.dataComponentProps, match.dataOverlayId, match.dataStyle);

      outBody = outBody.replace(OverlaidComposerExtension._serializedReplacerRe(match.dataOverlayId), anchorTag)
    }

    outDraft.body = outBody;
    return outDraft;
  }
}
