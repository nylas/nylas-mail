import RealDOMParser from './real-dom-parser'

export default class IFrameSearcher {
  /**
   * An imperative renderer for iframes
   */
  static highlightSearchInDocument(regionId, searchTerm, doc, searchIndex) {
    const parser = new RealDOMParser(regionId)
    if (parser.matchesSearch(doc, searchTerm)) {
      parser.removeMatchesAndNormalize(doc)
      const matchNodeMap = parser.getElementsWithNewMatchNodes(doc, searchTerm, searchIndex)
      parser.highlightSearch(doc, matchNodeMap)
    } else {
      parser.removeMatchesAndNormalize(doc)
    }
  }
}
