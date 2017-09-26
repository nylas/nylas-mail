import _ from 'underscore';
import ReactDOM from 'react-dom';
import Utils from '../flux/models/utils';
import VirtualDOMParser from './virtual-dom-parser';
import SearchableComponentStore from '../flux/stores/searchable-component-store';

class SearchableComponent {
  componentDidMount(superMethod, ...args) {
    if (superMethod) superMethod.apply(this, args);
    this.__regionId = Utils.generateTempId();
    this._searchableListener = SearchableComponentStore.listen(() => {
      this._onSearchableComponentStoreChange();
    });
    SearchableComponentStore.registerSearchRegion(this.__regionId, ReactDOM.findDOMNode(this));
  }

  _onSearchableComponentStoreChange() {
    const searchIndex = SearchableComponentStore.getCurrentRegionIndex(this.__regionId);
    const { searchTerm } = SearchableComponentStore.getCurrentSearchData();
    this.setState({
      __searchTerm: searchTerm,
      __searchIndex: searchIndex,
    });
  }

  shouldComponentUpdate(superMethod, nextProps, nextState) {
    let shouldUpdate = true;
    if (superMethod) {
      shouldUpdate = superMethod.apply(this, [nextProps, nextState]);
    }
    if (
      shouldUpdate &&
      (this.__searchTerm || (this.__searchIndex !== null && this.__searchIndex !== undefined))
    ) {
      shouldUpdate =
        this.__searchTerm !== nextState.__searchTerm ||
        this.__searchIndex !== nextState.__searchIndex;
    }
    return shouldUpdate;
  }

  componentWillUnmount(superMethod, ...args) {
    if (superMethod) superMethod.apply(this, args);
    this._searchableListener();
    SearchableComponentStore.unregisterSearchRegion(this.__regionId);
  }

  componentDidUpdate(superMethod, ...args) {
    if (superMethod) superMethod.apply(this, args);
    SearchableComponentStore.registerSearchRegion(this.__regionId, ReactDOM.findDOMNode(this));
  }

  render(superMethod, ...args) {
    if (superMethod) {
      const vDOM = superMethod.apply(this, args);
      const parser = new VirtualDOMParser(this.__regionId);
      const searchTerm = this.state.__searchTerm;
      if (parser.matchesSearch(vDOM, searchTerm)) {
        const normalizedDOM = parser.removeMatchesAndNormalize(vDOM);
        const matchNodeMap = parser.getElementsWithNewMatchNodes(
          normalizedDOM,
          searchTerm,
          this.state.__searchIndex
        );
        return parser.highlightSearch(normalizedDOM, matchNodeMap);
      }
      return vDOM;
    }
    return null;
  }
}

/**
 * Takes a React component and makes it searchable
 */
export default class SearchableComponentMaker {
  static extend(component) {
    const proto = SearchableComponent.prototype;
    for (const propName of Object.getOwnPropertyNames(proto)) {
      const origMethod = component.prototype[propName];
      if (origMethod) {
        if (propName === 'constructor') {
          continue;
        }
        component.prototype[propName] = _.partial(proto[propName], origMethod);
      } else {
        component.prototype[propName] = proto[propName];
      }
    }
    return component;
  }

  static searchInIframe(contentDocument) {
    return contentDocument;
  }
}
