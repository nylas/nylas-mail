import React from 'react'
import KeyCommandsRegion from '../key-commands-region'

function ListensToMovementKeys(ComposedComponent) {
  return class extends ComposedComponent {
    static displayName = ComposedComponent.displayName
    static containerRequired = ComposedComponent.containerRequired;
    static containerStyles = ComposedComponent.containerStyles;

    localKeyHandlers() {
      return {
        'core:previous-item': (event) => {
          if (!(this.refs.composed || {}).onArrowUp) { return }
          event.stopPropagation();
          this.refs.composed.onArrowUp(event)
        },
        'core:next-item': (event) => {
          if (!(this.refs.composed || {}).onArrowDown) { return }
          event.stopPropagation();
          this.refs.composed.onArrowDown(event)
        },
        'core:move-left': (event) => {
          if (!(this.refs.composed || {}).onArrowDown) { return }
          event.stopPropagation();
          this.refs.composed.onArrowLeft(event)
        },
        'core:move-right': (event) => {
          if (!(this.refs.composed || {}).onArrowDown) { return }
          event.stopPropagation();
          this.refs.composed.onArrowRight(event)
        },
      };
    }

    onKeyDown = (event) => {
      if (['Enter', 'Return'].includes(event.key)) {
        if (!(this.refs.composed || {}).onEnter) { return }
        event.stopPropagation();
        this.refs.composed.onEnter(event)
      }
      if (event.key === 'Tab') {
        if (event.shiftKey) {
          if (!(this.refs.composed || {}).onShiftTab) { return }
          event.stopPropagation();
          event.preventDefault();
          this.refs.composed.onShiftTab(event)
        } else {
          if (!(this.refs.composed || {}).onTab) { return }
          event.stopPropagation();
          event.preventDefault();
          this.refs.composed.onTab(event)
        }
      }
    }

    render() {
      return (
        <KeyCommandsRegion
          tabIndex="0"
          localHandlers={this.localKeyHandlers()}
          onKeyDown={this.onKeyDown}
        >
          <ComposedComponent ref="composed" {...this.props} />
        </KeyCommandsRegion>
      )
    }
  }
}

export default ListensToMovementKeys
