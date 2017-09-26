import React from 'react';
import KeyCommandsRegion from '../key-commands-region';

function ListensToMovementKeys(ComposedComponent) {
  return class extends ComposedComponent {
    static displayName = ComposedComponent.displayName;
    static containerRequired = ComposedComponent.containerRequired;
    static containerStyles = ComposedComponent.containerStyles;

    localKeyHandlers() {
      return {
        'core:previous-item': event => {
          if (!(this._component || {}).onArrowUp) {
            return;
          }
          event.stopPropagation();
          this._component.onArrowUp(event);
        },
        'core:next-item': event => {
          if (!(this._component || {}).onArrowDown) {
            return;
          }
          event.stopPropagation();
          this._component.onArrowDown(event);
        },
        'core:move-left': event => {
          if (!(this._component || {}).onArrowDown) {
            return;
          }
          event.stopPropagation();
          this._component.onArrowLeft(event);
        },
        'core:move-right': event => {
          if (!(this._component || {}).onArrowDown) {
            return;
          }
          event.stopPropagation();
          this._component.onArrowRight(event);
        },
      };
    }

    onKeyDown = event => {
      if (['Enter', 'Return'].includes(event.key)) {
        if (!(this._component || {}).onEnter) {
          return;
        }
        event.stopPropagation();
        this._component.onEnter(event);
      }
      if (event.key === 'Tab') {
        if (event.shiftKey) {
          if (!(this._component || {}).onShiftTab) {
            return;
          }
          event.stopPropagation();
          event.preventDefault();
          this._component.onShiftTab(event);
        } else {
          if (!(this._component || {}).onTab) {
            return;
          }
          event.stopPropagation();
          event.preventDefault();
          this._component.onTab(event);
        }
      }
    };

    render() {
      return (
        <KeyCommandsRegion
          tabIndex="0"
          localHandlers={this.localKeyHandlers()}
          onKeyDown={this.onKeyDown}
        >
          <ComposedComponent
            ref={cm => {
              this._component = cm;
            }}
            {...this.props}
          />
        </KeyCommandsRegion>
      );
    }
  };
}

export default ListensToMovementKeys;
