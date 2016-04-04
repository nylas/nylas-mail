/** @babel */
import React, {Component, PropTypes} from 'react';
import ReactDOM from 'react-dom';
import {Actions, FocusedPerspectiveStore} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';
import SnoozePopover from './snooze-popover';


class SnoozeButton extends Component {

  static propTypes = {
    className: PropTypes.string,
    threads: PropTypes.array,
    direction: PropTypes.string,
    renderImage: PropTypes.bool,
    getBoundingClientRect: PropTypes.func,
  };

  static defaultProps = {
    className: 'btn btn-toolbar',
    direction: 'down',
    renderImage: true,
  };

  onClick = (event)=> {
    event.stopPropagation()
    const buttonRect = this.getBoundingClientRect()
    Actions.openPopover(
      <SnoozePopover
        threads={this.props.threads}
        closePopover={Actions.closePopover} />,
      {originRect: buttonRect, direction: this.props.direction}
    )
  };

  getBoundingClientRect = ()=> {
    if (this.props.getBoundingClientRect) {
      return this.props.getBoundingClientRect()
    }
    return ReactDOM.findDOMNode(this).getBoundingClientRect()
  };

  render() {
    if (!FocusedPerspectiveStore.current().isInbox()) {
      return <span />;
    }
    return (
      <button
        title="Snooze"
        tabIndex={-1}
        className={"snooze-button " + this.props.className}
        onClick={this.onClick}>
        {this.props.renderImage ?
          <RetinaImg
            name="toolbar-snooze.png"
            mode={RetinaImg.Mode.ContentIsMask} /> :
          void 0
        }
      </button>
    );
  }
}


export class QuickActionSnooze extends Component {
  static displayName = 'QuickActionSnooze';

  static propTypes = {
    thread: PropTypes.object,
  };

  getBoundingClientRect = ()=> {
    // Grab the parent node because of the zoom applied to this button. If we
    // took this element directly, we'd have to divide everything by 2
    const element = ReactDOM.findDOMNode(this).parentNode;
    const {height, width, top, bottom, left, right} = element.getBoundingClientRect()

    // The parent node is a bit too much to the left, lets adjust this.
    return {height, width, top, bottom, right, left: left + 5}
  };

  static containerRequired = false;

  render() {
    if (!FocusedPerspectiveStore.current().isInbox()) {
      return <span />;
    }
    return (
      <SnoozeButton
        direction="left"
        renderImage={false}
        threads={[this.props.thread]}
        className="btn action action-snooze"
        getBoundingClientRect={this.getBoundingClientRect} />
    );
  }
}


export class ToolbarSnooze extends Component {
  static displayName = 'ToolbarSnooze';

  static propTypes = {
    items: PropTypes.array,
  };

  static containerRequired = false;

  render() {
    if (!FocusedPerspectiveStore.current().isInbox()) {
      return <span />;
    }
    return (
      <SnoozeButton threads={this.props.items}/>
    );
  }
}
