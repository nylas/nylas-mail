import React, {Component, PropTypes} from 'react';
import _ from 'underscore';
import {exec} from 'child_process';

const Phase = {
  // No wheel events received yet, container is inactive.
  None: 'none',

  // Wheel events received
  GestureStarting: 'gesture-starting',

  // Wheel events received and we are stopping event propagation.
  GestureConfirmed: 'gesture-confirmed',

  // Fingers lifted, we are animating to a final state.
  Settling: 'settling',
}

let SwipeInverted = false;

if (process.platform === 'darwin') {
  exec("defaults read -g com.apple.swipescrolldirection", (err, stdout)=> {
    if (err !== null) {
      return;
    }
    if (stdout.toString().trim() === '1') {
      SwipeInverted = true;
    }
  });
} else if (process.platform === 'win32') {
  // Currently does not matter because we don't support trackpad gestures on Win.
  // It appears there's a config key called FlipFlopWheel which we might have to
  // check, but it also looks like disabling natural scroll on Win32 only changes
  // vertical, not horizontal, behavior.
}


export default class SwipeContainer extends Component {
  static displayName = 'SwipeContainer';

  static propTypes = {
    children: PropTypes.object.isRequired,
    onSwipeLeft: React.PropTypes.func,
    onSwipeLeftClass: React.PropTypes.string,
    onSwipeRight: React.PropTypes.func,
    onSwipeRightClass: React.PropTypes.string,
  };

  constructor(props) {
    super(props);
    this.tracking = false;
    this.trackingTouchIdentifier = null;
    this.phase = Phase.None;
    this.fired = false;
    this.state = {
      fullDistance: 'unknown',
      velocity: 0,
      currentX: 0,
      targetX: 0,
    };
  }

  componentDidMount() {
    window.addEventListener('scroll-touch-begin', this._onScrollTouchBegin);
    window.addEventListener('scroll-touch-end', this._onScrollTouchEnd);
  }

  componentDidUpdate() {
    if (this.phase === Phase.Settling) {
      window.requestAnimationFrame(()=> {
        if (this.phase === Phase.Settling) {
          this._settle();
        }
      });
    }
  }
  componentWillUnmount() {
    this.phase = Phase.None;
    window.removeEventListener('scroll-touch-begin', this._onScrollTouchBegin);
    window.removeEventListener('scroll-touch-end', this._onScrollTouchEnd);
  }

  _isEnabled = ()=> {
    return (this.props.onSwipeLeft || this.props.onSwipeRight);
  }

  _onWheel = (e)=> {
    let velocity = e.deltaX / 3;
    if (SwipeInverted) {
      velocity = -velocity;
    }
    this._onDragWithVelocity(velocity);

    if (this.phase === Phase.GestureConfirmed) {
      e.preventDefault();
    }
  }

  _onDragWithVelocity = (velocity)=> {
    if ((this.tracking === false) || !this._isEnabled()) {
      return;
    }
    const velocityConfirmsGesture = Math.abs(velocity) > 3;

    if (this.phase === Phase.None) {
      this.phase = Phase.GestureStarting;
    }

    if (velocityConfirmsGesture || (this.phase === Phase.Settling)) {
      this.phase = Phase.GestureConfirmed;
    }

    let {fullDistance, thresholdDistance} = this.state;

    if (fullDistance === 'unknown') {
      fullDistance = React.findDOMNode(this).clientWidth;
      thresholdDistance = 110;
    }

    const currentX = Math.max(-fullDistance, Math.min(fullDistance, this.state.currentX + velocity));
    const estimatedSettleX = currentX + velocity * 8;
    let targetX = 0;

    if (this.props.onSwipeRight && (estimatedSettleX > thresholdDistance)) {
      targetX = fullDistance;
    }
    if (this.props.onSwipeLeft && (estimatedSettleX < -thresholdDistance)) {
      targetX = -fullDistance;
    }
    this.setState({thresholdDistance, fullDistance, velocity, currentX, targetX});
  }

  _onScrollTouchBegin = ()=> {
    this.tracking = true;
  }

  _onScrollTouchEnd = ()=> {
    this.tracking = false;
    if (this.phase !== Phase.None) {
      this.phase = Phase.Settling;
      this.fired = false;
      this._settle();
    }
  }

  _onTouchStart = (e)=> {
    if ((this.trackingTouchIdentifier === null) && (e.targetTouches.length > 0)) {
      const touch = e.targetTouches.item(0);
      this.trackingTouchIdentifier = touch.identifier;
      this.trackingTouchX = touch.clientX;
      this._onScrollTouchBegin();
    }
  }

  _onTouchMove = (e)=> {
    if (this.trackingTouchIdentifier === null) {
      return;
    }
    if (e.cancelable === false) {
      // Chrome has already started interpreting these touch events as a scroll.
      // We can no longer call preventDefault to make them ours.
      return;
    }
    let trackingTouch = null;
    for (let ii = 0; ii < e.changedTouches.length; ii++) {
      const touch = e.changedTouches.item(ii);
      if (touch.identifier === this.trackingTouchIdentifier) {
        trackingTouch = touch;
        break;
      }
    }
    if (trackingTouch !== null) {
      const velocity = (trackingTouch.clientX - this.trackingTouchX);
      this.trackingTouchX = trackingTouch.clientX;
      this._onDragWithVelocity(velocity);

      if (this.phase === Phase.GestureConfirmed) {
        e.preventDefault();
      }
    }
  }

  _onTouchEnd = (e)=> {
    if (this.trackingTouchIdentifier === null) {
      return;
    }
    for (let ii = 0; ii < e.changedTouches.length; ii++) {
      if (e.changedTouches.item(ii).identifier === this.trackingTouchIdentifier) {
        this.trackingTouchIdentifier = null;
        this._onScrollTouchEnd();
        break;
      }
    }
  }

  _settle() {
    const {currentX, targetX} = this.state;
    let {velocity} = this.state;
    let step = 0;

    let shouldFire = false;
    let shouldFinish = false;

    if (targetX === 0) {
      // settle
      step = (targetX - currentX) / 6.0;
      shouldFinish = (Math.abs(step) < 0.05);
    } else {
      // accelerate offscreen
      if (Math.abs(velocity) < Math.abs((targetX - currentX) / 48.0)) {
        velocity = (targetX - currentX) / 48.0;
      } else {
        velocity = velocity * 1.08;
      }
      step = velocity;

      const fraction = Math.abs(currentX) / Math.abs(targetX);
      shouldFire = ((fraction >= 0.8) && (!this.fired));
      shouldFinish = (fraction >= 1.0);
    }

    if (shouldFire) {
      this.fired = true;
      if (targetX > 0) {
        this.props.onSwipeRight();
      }
      if (targetX < 0) {
        this.props.onSwipeLeft();
      }
    }

    if (shouldFinish) {
      this.phase = Phase.None;
      this.setState({
        velocity: 0,
        currentX: targetX,
        targetX: targetX,
        thresholdDistance: 'unknown',
        fullDistance: 'unknown',
      });
    } else {
      this.phase = Phase.Settling;
      this.setState({
        velocity: velocity,
        currentX: currentX + step,
      });
    }
  }

  render() {
    const {currentX, targetX} = this.state;
    const otherProps = _.omit(this.props, _.keys(this.constructor.propTypes));

    const backingStyles = {top: 0, bottom: 0, position: 'absolute'};
    let backingClass = 'swipe-backing';

    if (currentX < 0) {
      backingClass += ' ' + this.props.onSwipeLeftClass;
      backingStyles.right = 0;
      backingStyles.width = -currentX + 1;
      if (targetX < 0) {
        backingClass += ' confirmed';
      }
    } else if (currentX > 0) {
      backingClass += ' ' + this.props.onSwipeRightClass;
      backingStyles.left = 0;
      backingStyles.width = currentX + 1;
      if (targetX > 0) {
        backingClass += ' confirmed';
      }
    }
    return (
      <div onWheel={this._onWheel}
           onTouchStart={this._onTouchStart}
           onTouchMove={this._onTouchMove}
           onTouchEnd={this._onTouchEnd}
           onTouchCancel={this._onTouchEnd}
           {...otherProps}>
        <div style={backingStyles} className={backingClass}></div>
        <div style={{transform: 'translate3d(' + currentX + 'px, 0, 0)'}}>
          {this.props.children}
        </div>
      </div>
    );
  }
}
