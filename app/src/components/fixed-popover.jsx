import _ from 'underscore';
import React, { Component } from 'react';
import { findDOMNode } from 'react-dom';
import PropTypes from 'prop-types';

import Actions from '../flux/actions';
import compose from './decorators/compose';
import AutoFocuses from './decorators/auto-focuses';

const Directions = {
  Up: 'up',
  Down: 'down',
  Left: 'left',
  Right: 'right',
};

const InverseDirections = {
  [Directions.Up]: Directions.Down,
  [Directions.Down]: Directions.Up,
  [Directions.Left]: Directions.Right,
  [Directions.Right]: Directions.Left,
};

const OFFSET_PADDING = 11.5;

/*
 * Renders a popover absultely positioned in the window next to the provided
 * rect.
 * If `Actions.openPopover` is called when the popover is already open, it will
 * close the previous one and open the new one.
 * @class FixedPopover
 **/
class FixedPopover extends Component {
  static Directions = Directions;

  static propTypes = {
    children: PropTypes.element,
    direction: PropTypes.string,
    fallbackDirection: PropTypes.string,
    closeOnAppBlur: PropTypes.bool,
    originRect: PropTypes.shape({
      bottom: PropTypes.number,
      top: PropTypes.number,
      right: PropTypes.number,
      left: PropTypes.number,
      height: PropTypes.number,
      width: PropTypes.number,
    }),
    focusElementWithTabIndex: PropTypes.func,
  };

  static defaultProps = {
    closeOnAppBlur: true,
  };

  constructor(props) {
    super(props);
    this.mounted = false;
    this.updateCount = 0;
    this.fallback = this.props.fallbackDirection;
    this.state = {
      offset: {},
      direction: props.direction,
      visible: false,
    };
  }

  componentDidMount() {
    this.mounted = true;
    findDOMNode(this.refs.popoverContainer).addEventListener('animationend', this.onAnimationEnd);
    window.addEventListener('resize', this.onWindowResize);
    _.defer(this.onPopoverRendered);
  }

  componentWillReceiveProps(nextProps) {
    this.fallback = nextProps.fallbackDirection;
    this.setState({ direction: nextProps.direction });
  }

  shouldComponentUpdate(nextProps, nextState) {
    return !_.isEqual(this.state, nextState) || !_.isEqual(this.props, nextProps);
  }

  componentDidUpdate() {
    _.defer(this.onPopoverRendered);
  }

  componentWillUnmount() {
    this.mounted = false;
    findDOMNode(this.refs.popoverContainer).removeEventListener(
      'animationend',
      this.onAnimationEnd
    );
    window.removeEventListener('resize', this.onWindowResize);
  }

  onAnimationEnd = () => {
    _.defer(this.props.focusElementWithTabIndex);
  };

  onWindowResize() {
    Actions.closePopover();
  }

  onPopoverRendered = () => {
    if (!this.mounted) {
      return;
    }

    const { direction } = this.state;
    const currentRect = this.getCurrentRect();
    const windowDimensions = this.getWindowDimensions();
    const newState = this.computeAdjustedOffsetAndDirection({
      direction,
      windowDimensions,
      currentRect,
    });
    if (newState) {
      if (this.updateCount > 1) {
        this.setState({ direction: this.props.direction, offset: {}, visible: true });
        return;
      }

      // Reset fallback after using it once
      this.fallback = null;
      this.updateCount++;
      this.setState(newState);
    } else {
      this.setState({ visible: true });
    }
  };

  onBlur = event => {
    const target = event.nativeEvent.relatedTarget;
    if (!this.props.closeOnAppBlur && target === null) {
      return;
    }
    if (!target || !findDOMNode(this).contains(target)) {
      Actions.closePopover();
    }
  };

  onKeyDown = event => {
    if (event.key === 'Escape') {
      Actions.closePopover();
    }
  };

  getCurrentRect = () => {
    return findDOMNode(this.refs.popover).getBoundingClientRect();
  };

  getWindowDimensions = () => {
    return {
      width: document.body.clientWidth,
      height: document.body.clientHeight,
    };
  };

  computeOverflows = ({ currentRect, windowDimensions }) => {
    const overflows = {
      top: currentRect.top < 0,
      left: currentRect.left < 0,
      bottom: currentRect.bottom > windowDimensions.height,
      right: currentRect.right > windowDimensions.width,
    };
    const overflowValues = {
      top: Math.abs(currentRect.top),
      left: Math.abs(currentRect.left),
      bottom: Math.abs(currentRect.bottom - windowDimensions.height),
      right: Math.abs(currentRect.right - windowDimensions.width),
    };
    return { overflows, overflowValues };
  };

  computeAdjustedOffsetAndDirection = ({
    direction,
    currentRect,
    windowDimensions,
    fallback = this.fallback,
    offsetPadding = OFFSET_PADDING,
  }) => {
    const { overflows, overflowValues } = this.computeOverflows({ currentRect, windowDimensions });
    const overflowCount = Object.keys(_.pick(overflows, val => val === true)).length;

    if (overflowCount > 0) {
      if (fallback) {
        return { direction: fallback, offset: {} };
      }

      const isHorizontalDirection = [Directions.Left, Directions.Right].includes(direction);
      const isVerticalDirection = [Directions.Up, Directions.Down].includes(direction);
      const shouldInvertDirection =
        (isHorizontalDirection && (overflows.left || overflows.right)) ||
        (isVerticalDirection && (overflows.top || overflows.bottom));
      const offset = {};
      let newDirection = direction;

      if (shouldInvertDirection) {
        newDirection = InverseDirections[direction];
      }

      if (isHorizontalDirection && (overflows.top || overflows.bottom)) {
        const overflowVal = overflows.top ? overflowValues.top : overflowValues.bottom;
        let offsetY = overflowVal + offsetPadding;

        offsetY = overflows.bottom ? -offsetY : offsetY;
        offset.y = offsetY;
      }
      if (isVerticalDirection && (overflows.left || overflows.right)) {
        const overflowVal = overflows.left ? overflowValues.left : overflowValues.right;
        let offsetX = overflowVal + offsetPadding;

        offsetX = overflows.right ? -offsetX : offsetX;
        offset.x = offsetX;
      }
      return { offset, direction: newDirection };
    }
    return null;
  };

  computePopoverStyles = ({ originRect, direction, offset }) => {
    const { Up, Down, Left, Right } = Directions;
    let containerStyle = {};
    let popoverStyle = {};
    let pointerStyle = {};

    switch (direction) {
      case Up:
        containerStyle = {
          // Place container on the top left corner of the rect
          top: originRect.top,
          left: originRect.left,
          width: originRect.width,
        };
        popoverStyle = {
          // Center, place on top of container, and adjust 10px for the pointer
          transform: `translate(${offset.x || 0}px) translate(-50%, calc(-100% - 10px))`,
          left: originRect.width / 2,
        };
        pointerStyle = {
          // Center, and place on top of our container
          transform: 'translate(-50%, -100%)',
          left: originRect.width, // Don't divide by 2 because of zoom
        };
        break;
      case Down:
        containerStyle = {
          // Place container on the bottom left corner of the rect
          top: originRect.top + originRect.height,
          left: originRect.left,
          width: originRect.width,
        };
        popoverStyle = {
          // Center and adjust 10px for the pointer (already positioned at the bottom of container)
          transform: `translate(${offset.x || 0}px) translate(-50%, 10px)`,
          left: originRect.width / 2,
        };
        pointerStyle = {
          // Center, already positioned at the bottom of container
          transform: 'translate(-50%, 0) rotateX(180deg)',
          left: originRect.width, // Don't divide by 2 because of zoom
        };
        break;
      case Left:
        containerStyle = {
          // Place container on the top left corner of the rect
          top: originRect.top,
          left: originRect.left,
          height: originRect.height,
        };
        popoverStyle = {
          // Center, place on left of container, and adjust 10px for the pointer
          transform: `translate(0, ${offset.y || 0}px) translate(calc(-100% - 10px), -50%)`,
          top: originRect.height / 2,
        };
        pointerStyle = {
          // Center, and place on left of our container (adjust for rotation)
          transform: 'translate(calc(-100% + 13px), -50%) rotate(270deg)',
          top: originRect.height, // Don't divide by 2 because of zoom
        };
        break;
      case Right:
        containerStyle = {
          // Place container on the top right corner of the rect
          top: originRect.top,
          left: originRect.left + originRect.width,
          height: originRect.height,
        };
        popoverStyle = {
          // Center and adjust 10px for the pointer
          transform: `translate(0, ${offset.y || 0}px) translate(10px, -50%)`,
          top: originRect.height / 2,
        };
        pointerStyle = {
          // Center, already positioned at the right of container (adjust for rotation)
          transform: 'translate(-12px, -50%) rotate(90deg)',
          top: originRect.height, // Don't divide by 2 because of zoom
        };
        break;
      default:
        break;
    }

    // Set the zoom directly on the style element. Otherwise it won't work with
    // mask image of our shadow pointer element. This is probably a Chrome bug
    pointerStyle.zoom = 0.5;

    return { containerStyle, popoverStyle, pointerStyle };
  };

  render() {
    const { offset, direction, visible } = this.state;
    const { children, originRect } = this.props;
    const blurTrapStyle = {
      top: originRect.top,
      left: originRect.left,
      height: originRect.height,
      width: originRect.width,
    };
    const { containerStyle, popoverStyle, pointerStyle } = this.computePopoverStyles({
      originRect,
      direction,
      offset,
    });
    const animateClass = visible ? ' popout' : '';

    return (
      <div>
        <div ref="blurTrap" className="fixed-popover-blur-trap" style={blurTrapStyle} />
        <div
          ref="popoverContainer"
          style={containerStyle}
          className={`fixed-popover-container${animateClass}`}
          onKeyDown={this.onKeyDown}
          onBlur={this.onBlur}
        >
          <div ref="popover" className={`fixed-popover`} style={popoverStyle}>
            {children}
          </div>
          <div className={`fixed-popover-pointer`} style={pointerStyle} />
          <div className={`fixed-popover-pointer shadow`} style={pointerStyle} />
        </div>
      </div>
    );
  }
}

export default compose(FixedPopover, AutoFocuses);
