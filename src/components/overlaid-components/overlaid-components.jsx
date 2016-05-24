import _ from 'underscore'
import React from 'react'
import ReactDOM from 'react-dom'
import Utils from '../../flux/models/utils'
import CustomContenteditableComponents from './custom-contenteditable-components'
import {ANCHOR_CLASS, IMG_SRC} from './anchor-constants'

const MUTATION_CONFIG = {
  subtree: true,
  childList: true,
  attributes: true,
  characterData: true,
  attributeOldValue: true,
  characterDataOldValue: true,
}

export default class OverlaidComponents extends React.Component {
  static displayName = "OverlaidComponents";

  static propTypes = {
    children: React.PropTypes.node,
    exposedProps: React.PropTypes.object,
  }

  static defaultProps = {
    children: false,
    exposedProps: {},
  }

  static WRAP_CLASS = "n1-overlaid-component-wrap";

  static propsToDOMAttr(props) {
    return JSON.stringify(props).replace(/"/g, "&quot;")
  }

  static buildAnchorTag(componentKey, props = {}, existingId = null, style = "") {
    const id = existingId || Utils.generateTempId()
    let className = ANCHOR_CLASS
    if (props.className) { className = `${className} ${props.className}` }
    const propsStr = OverlaidComponents.propsToDOMAttr(props);
    return `<img class="${className}" src="${IMG_SRC}" data-overlay-id="${id}" data-component-props="${propsStr}" data-component-key="${componentKey}" style="${style}">`
  }

  constructor(props) {
    super(props);
    this.state = {
      anchorRectIds: [],
      serialized: false,
    }
    this._anchorData = {}
    this._overlayData = {}
    this.observeOverlays = new MutationObserver(this._updateAnchors)
    this.observeAnchors = new MutationObserver(this._updateOverlays)
  }

  componentDidMount() {
    this._updateAnchors();
    this._updateOverlays();
    this._setupMutationObservers()
  }

  componentWillUpdate() {
    this._teardownMutationObservers()
  }

  componentDidUpdate() {
    this._updateAnchors();
    this._updateOverlays();
    this._setupMutationObservers();
  }

  componentWillUnmount() {
    this._teardownMutationObservers()
  }

  _setupMutationObservers() {
    this.observeOverlays.disconnect()
    this.observeOverlays.observe(
      ReactDOM.findDOMNode(this.refs.overlaidComponents),
      MUTATION_CONFIG
    )
    this.observeAnchors.disconnect()
    this.observeAnchors.observe(
      ReactDOM.findDOMNode(this.refs.anchorContainer),
      MUTATION_CONFIG
    )
  }

  _teardownMutationObservers() {
    this.observeOverlays.disconnect()
    this.observeAnchors.disconnect()
  }

  _updateAnchors = () => {
    this._teardownMutationObservers();
    const lastRects = _.clone(this._overlayData);
    this._overlayData = this._dataFromNodes({
      root: this.refs.overlaidComponents,
      selector: `.${OverlaidComponents.WRAP_CLASS}`,
      dataFields: [],
    })
    if (_.isEqual(lastRects, this._overlayData)) { return }
    this._adjustNodes("anchorContainer", this._overlayData, ["width", "height"]);
    this._setupMutationObservers()
  }

  _updateOverlays = () => {
    this._teardownMutationObservers();
    const lastRects = _.clone(this._anchorData)
    this._anchorData = this._dataFromNodes({
      root: this.refs.anchorContainer,
      selector: `.${ANCHOR_CLASS}`,
      dataFields: ["componentProps", "componentKey"],
    })
    if (_.isEqual(lastRects, this._anchorData)) { return }
    this._adjustNodes("overlaidComponents", this._anchorData, ["top", "left"]);
    this._setupMutationObservers();
    if (!_.isEqual(this.state.anchorRectIds, Object.keys(this._anchorData))) {
      this.setState({anchorRectIds: Object.keys(this._anchorData)})
    }
  }

  _adjustNodes(ref, rects, dims) {
    const root = ReactDOM.findDOMNode(this.refs[ref]);
    for (const id of Object.keys(rects)) {
      const node = root.querySelector(`[data-overlay-id=${id}]`);
      if (!node) { continue }
      for (const dim of dims) {
        const dimVal = rects[id][dim];
        node.style[dim] = `${dimVal}px`
      }
    }
  }

  _dataFromNodes({root, selector, dataFields}) {
    const updatedRegistry = {}
    const nodes = Array.from(root.querySelectorAll(selector));
    if (nodes.length === 0) { return updatedRegistry }
    const rootRect = root.getBoundingClientRect();
    for (const node of nodes) {
      const id = node.dataset.overlayId;
      const rawRect = node.getBoundingClientRect();
      const adjustedRect = {
        left: rawRect.left - rootRect.left,
        top: rawRect.top - rootRect.top,
        width: rawRect.width,
        height: rawRect.height,
      }
      updatedRegistry[id] = adjustedRect;
      for (const field of dataFields) {
        updatedRegistry[id][field] = node.dataset[field]
      }
    }
    return updatedRegistry
  }

  _renderSerializeToggle() {
    let msg = "Preview as recipient";
    if (this.state.serialized) {
      msg = "Return to editor"
    }
    return <a className="toggle-serialized" onClick={() => { this.setState({serialized: !this.state.serialized}) }}>{msg}</a>
  }

  _renderOverlaidComponents() {
    const els = [];
    for (const id of this.state.anchorRectIds) {
      const data = this._anchorData[id];
      if (!data) { throw new Error("No mounted rect for #{id}") }

      const style = {left: data.left, top: data.top, position: "relative"}
      const componentData = CustomContenteditableComponents.get(data.componentKey);

      if (!componentData) {
        // It's possible that the plugin with that will register this
        // componentKey hasn't loaded yet. This is common in popout
        // composers where 3rd party plugins are loaded later.
        continue
      }

      const component = this.state.serialized ? componentData.serialized : componentData.main;

      if (!component) { throw new Error(`No registered component for ${data.componentKey}`) }

      let props = JSON.parse(data.componentProps);

      props = Object.assign({}, this.props.exposedProps, props);

      const el = React.createElement(component, props)

      const wrap = (
        <div
          className={OverlaidComponents.WRAP_CLASS}
          style={style}
          data-overlay-id={id}
        >
          {el}
        </div>
      )

      els.push(wrap)
    }
    const toggle = (els.length > 0) ? this._renderSerializeToggle() : false
    return (
      <div ref="overlaidComponents" className="overlaid-components">
        {toggle}
        {els}
      </div>
    )
  }

  render() {
    return (
      <div className="overlaid-components-wrap" style={{position: "relative"}}>
        <div className="anchor-container" ref="anchorContainer">
          {this.props.children}
        </div>
        {this._renderOverlaidComponents()}
      </div>
    )
  }
}
