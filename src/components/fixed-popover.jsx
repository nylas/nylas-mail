import _ from 'underscore';
import React, {Component, PropTypes} from 'react';


// TODO
// This is a temporary hack for the snooze popover
// This should be the actual dimensions of the rendered popover body
const OVERFLOW_LIMIT = 50;

/**
 * Renders a popover absultely positioned in the window next to the provided
 * rect.
 * This popover will not automatically be closed. The user must completely
 * control the lifecycle of the Popover via `Actions.openPopover` and
 * `Actions.closePopover`
 * If `Actions.openPopover` is called when the popover is already open, it will
 * close the previous one and open the new one.
 * @class FixedPopover
 **/
class FixedPopover extends Component {

  static propTypes = {
    className: PropTypes.string,
    children: PropTypes.element,
    direction: PropTypes.string,
    showing: PropTypes.bool,
    originRect: PropTypes.shape({
      bottom: PropTypes.number,
      top: PropTypes.number,
      right: PropTypes.number,
      left: PropTypes.number,
      height: PropTypes.number,
      width: PropTypes.number,
    }),
  };

  constructor(props) {
    super(props);
    this.state = {
      offset: 0,
      dimensions: {},
    };
    this._focusOnOpen = props.showing;
  }

  componentWillReceiveProps(nextProps) {
    if (nextProps.showing === true) {
      this._focusOnOpen = true;
    }
  }

  componentDidUpdate() {
    if (this._focusOnOpen) {
      this._focusImportantElement()
      this._focusOnOpen = false
    }
  }

  _focusImportantElement = ()=> {
    // Automatically focus the element inside us with the lowest tab index
    const popover = React.findDOMNode(this.refs.popover)

    // _.sortBy ranks in ascending numerical order.
    const matches = _.sortBy(popover.querySelectorAll("[tabIndex], input"), (node)=> {
      if (node.tabIndex > 0) {
        return node.tabIndex;
      } else if (node.nodeName === "INPUT") {
        return 1000000
      }
      return 1000001
    })
    if (matches[0]) {
      matches[0].focus();
    }
  };

  _getNewDirection = (direction, originRect, windowDimensions, limit = OVERFLOW_LIMIT)=> {
    // TODO this is a hack. Implement proper repositioning
    switch (direction) {
    case 'right':
      if (
        windowDimensions.width - (originRect.left + originRect.width) < limit ||
        originRect.top < limit * 2
      ) {
        return 'down';
      }
      if (windowDimensions.height - (originRect.top + originRect.height) < limit * 2) {
        return 'up'
      }
      break;
    case 'down':
      if (windowDimensions.height - (originRect.top + originRect.height) < limit * 4) {
        return 'up'
      }
      break;
    default:
      break;
    }
    return null;
  };

  _computePopoverPositions = (originRect, direction)=> {
    const windowDimensions = {
      width: document.body.clientWidth,
      height: document.body.clientHeight,
    }
    const newDirection = this._getNewDirection(direction, originRect, windowDimensions);
    if (newDirection != null) {
      return this._computePopoverPositions(originRect, newDirection);
    }
    let popoverStyle = {};
    let pointerStyle = {};
    let containerStyle = {};
    switch (direction) {
    case 'up':
      containerStyle = {
        bottom: (windowDimensions.height - originRect.top) + 10,
        left: originRect.left,
      }
      popoverStyle = {
        transform: 'translate(-50%, -100%)',
        left: originRect.width / 2,
      }
      pointerStyle = {
        transform: 'translate(-50%, 0)',
        left: originRect.width, // Don't divide by 2 because of zoom
      }
      break;
    case 'down':
      containerStyle = {
        top: originRect.top + originRect.height,
        left: originRect.left,
      }
      popoverStyle = {
        transform: 'translate(-50%, 10px)',
        left: originRect.width / 2,
      }
      pointerStyle = {
        transform: 'translate(-50%, 0) rotateX(180deg)',
        left: originRect.width, // Don't divide by 2 because of zoom
      }
      break;
    case 'left':
      containerStyle = {
        top: originRect.top,
        right: (windowDimensions.width - originRect.left) + 10,
      }
      // TODO This is a hack for the snooze popover. Fix this
      let popoverTop = originRect.height / 2;
      let popoverTransform = 'translate(-100%, -50%)';
      if (originRect.top < OVERFLOW_LIMIT * 2) {
        popoverTop = 0;
        popoverTransform = 'translate(-100%, 0)';
      } else if (windowDimensions.height - originRect.bottom < OVERFLOW_LIMIT * 2) {
        popoverTop = -190;
        popoverTransform = 'translate(-100%, 0)';
      }
      popoverStyle = {
        transform: popoverTransform,
        top: popoverTop,
      }
      pointerStyle = {
        transform: 'translate(-13px, -50%) rotate(270deg)',
        top: originRect.height, // Don't divide by 2 because of zoom
      }
      break;
    case 'right':
      containerStyle = {
        top: originRect.top,
        left: originRect.left + originRect.width,
      }
      popoverStyle = {
        transform: 'translate(10px, -50%)',
        top: originRect.height / 2,
      }
      pointerStyle = {
        transform: 'translate(-12px, -50%) rotate(90deg)',
        top: originRect.height, // Don't divide by 2 because of zoom
      }
      break;
    default:
      break;
    }

    // Set the zoom directly on the style element. Otherwise it won't work with
    // mask image of our shadow pointer element. This is probably a Chrome bug
    pointerStyle.zoom = 0.5;

    return {containerStyle, popoverStyle, pointerStyle};
  };

  render() {
    const {children, direction, showing, originRect} = this.props;
    const {containerStyle, popoverStyle, pointerStyle} = this._computePopoverPositions(originRect, direction);

    if (!showing) {
      return <span />;
    }
    return (
      <div
        style={containerStyle}
        className="nylas-fixed-popover-container"
        onKeyDown={this._onKeyDown}>
        <div ref="popover" className="fixed-popover" style={popoverStyle}>
          {children}
        </div>
        <div className="fixed-popover-pointer" style={pointerStyle} />
        <div className="fixed-popover-pointer shadow" style={pointerStyle} />
      </div>
    );
  }

}

export default FixedPopover;
