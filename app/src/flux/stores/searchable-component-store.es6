import _ from 'underscore';
import MailspringStore from 'mailspring-store';
import DOMUtils from '../../dom-utils';
import Actions from '../actions';
import { MAX_MATCHES, CHAR_THRESHOLD } from '../../searchable-components/search-constants';
import FocusedContentStore from './focused-content-store';

class SearchableComponentStore extends MailspringStore {
  constructor() {
    super();
    this.currentMatch = null;
    this.matches = [];
    this.globalIndex = null; // null means nothing is selected
    this.scrollAncestor = null;

    // null and empty string are different. Null means that search isn't
    // even activated. Empty string means we're active but just not
    // searching anything.
    this.searchTerm = null;

    this.searchRegions = {};

    this._lastThread = FocusedContentStore.focused('thread');

    this.listenTo(Actions.findInThread, this._findInThread);
    this.listenTo(Actions.nextSearchResult, this._nextSearchResult);
    this.listenTo(Actions.previousSearchResult, this._previousSearchResult);
    this.listenTo(FocusedContentStore, () => {
      const newThread = FocusedContentStore.focused('thread');
      if (newThread !== this._lastThread) {
        this._findInThread(null);
        this._lastThread = newThread;
      }
    });
  }

  getCurrentRegionIndex(regionId) {
    let regionOffset = null;
    if (
      regionId &&
      this.currentMatch &&
      this.currentMatch.node.getAttribute('data-region-id') === regionId
    ) {
      regionOffset = +this.currentMatch.node.getAttribute('data-render-index');
    }
    return regionOffset;
  }

  getCurrentSearchData() {
    return {
      searchTerm: this.searchTerm,
      globalIndex: this.globalIndex,
      resultsLength: this.matches.length,
    };
  }

  scrollbarTicks() {
    let ticks = [];
    if (this.matches.length > 0 && this.scrollAncestor && this.scrollAncestor.scrollHeight > -1) {
      ticks = this.matches.map(match => {
        if (match === this.currentMatch) {
          return {
            percent: match.top / this.scrollAncestor.scrollHeight,
            className: 'match',
          };
        }
        return match.top / this.scrollAncestor.scrollHeight;
      });
    }
    return ticks;
  }

  _nextSearchResult = () => {
    this._moveGlobalIndexBy(1);
  };

  _previousSearchResult = () => {
    this._moveGlobalIndexBy(-1);
  };

  // This needs to be debounced since it's called when all of our
  // components are mounting and unmounting. It also is very expensive
  // since it calls `getBoundingClientRect` and will trigger repaints.
  _recalculateMatches = _.debounce(() => {
    this.matches = [];

    // searchNodes need to all be under the root document. matches
    // may contain nodes inside of iframes which are not attached ot the
    // root document.
    const searchNodes = [];

    if (this.searchTerm && this.searchTerm.length >= CHAR_THRESHOLD) {
      Object.values(this.searchRegions).forEach(node => {
        if (this.matches.length >= MAX_MATCHES) {
          return;
        }
        let refNode;
        let topOffset = 0;
        let leftOffset = 0;
        if (node.nodeName === 'IFRAME') {
          searchNodes.push(node);
          const iframeRect = node.getBoundingClientRect();
          topOffset = iframeRect.top;
          leftOffset = iframeRect.left;
          refNode = node.contentDocument.body;
          if (!refNode) {
            refNode = node.contentDocument;
          }
        } else {
          refNode = node;
        }
        const matches = refNode.querySelectorAll('search-match, .search-match');
        for (let i = 0; i < matches.length; i++) {
          if (!DOMUtils.nodeIsLikelyVisible(matches[i])) {
            continue;
          }
          const rect = matches[i].getBoundingClientRect();
          if (node.nodeName !== 'IFRAME') {
            searchNodes.push(matches[i]);
          }
          this.matches.push({
            node: matches[i],
            top: rect.top + topOffset,
            left: rect.left + leftOffset,
            height: rect.height,
          });
          if (this.matches.length >= MAX_MATCHES) {
            break;
          }
        }
      });
      this.matches.sort((nodeA, nodeB) => {
        const aScore = nodeA.top + nodeA.left / 1000;
        const bScore = nodeB.top + nodeB.left / 1000;
        return aScore - bScore;
      });

      if (this.globalIndex !== null) {
        this.globalIndex = Math.min(this.matches.length - 1, this.globalIndex);
        this.currentMatch = this.matches[this.globalIndex];
      }

      const parentFilter = node => {
        return _.contains(node.classList, 'scroll-region-content');
      };
      this.scrollAncestor = DOMUtils.commonAncestor(searchNodes, parentFilter);
      this.scrollAncestor = this.scrollAncestor.closest('.scroll-region-content');

      if (this.scrollAncestor) {
        const scrollRect = this.scrollAncestor.getBoundingClientRect();
        const scrollTop = scrollRect.top - this.scrollAncestor.scrollTop;
        // We save the position relative to the top of the scrollAncestor
        // instead of the current getBoudingClientRect (which is dependent
        // on the current scroll position)
        this.matches.forEach(match => {
          match.top -= scrollTop;
        });
      }
    } else {
      this.currentMatch = null;
      this.globalIndex = null;
      this.scrollAncestor = null;
    }

    if (this.matches.length > 0) {
      if (this.globalIndex === null) {
        this._moveGlobalIndexBy(1);
      } else {
        this._scrollIntoView();
      }
    }

    this.trigger();
  }, 33);

  _moveGlobalIndexBy(amount) {
    if (this.matches.length === 0) {
      return;
    }
    if (this.globalIndex === null) {
      this.globalIndex = 0;
    } else {
      this.globalIndex += amount;
      if (this.globalIndex < 0) {
        this.globalIndex += this.matches.length;
      } else {
        this.globalIndex = this.globalIndex % this.matches.length;
      }
    }
    this.currentMatch = this.matches[this.globalIndex];
    this._scrollIntoView();
    this.trigger();
  }

  _scrollIntoView() {
    if (!this.currentMatch || !this.currentMatch.node || !this.scrollAncestor) {
      return;
    }

    const visibleRect = this.scrollAncestor.getBoundingClientRect();
    const scrollTop = this.scrollAncestor.scrollTop;
    const matchMid = this.currentMatch.top + this.currentMatch.height / 2;

    if (matchMid < scrollTop || matchMid > scrollTop + visibleRect.height) {
      const viewportMid = scrollTop + visibleRect.height / 2;
      const delta = matchMid - viewportMid;
      this.scrollAncestor.scrollTop = this.scrollAncestor.scrollTop + delta;
    }
  }

  _findInThread = search => {
    if (search !== this.searchTerm) {
      this.searchTerm = search;
      this.trigger();
      this._recalculateMatches();
    }
  };

  registerSearchRegion(regionId, domNode) {
    this.searchRegions[regionId] = domNode;
    this._recalculateMatches();
  }

  unregisterSearchRegion(regionId) {
    delete this.searchRegions[regionId];
    this._recalculateMatches();
  }
}
export default new SearchableComponentStore();
