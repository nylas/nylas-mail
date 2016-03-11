import React from 'react';
import NylasStore from 'nylas-store'
import Actions from '../actions'
import FixedPopover from '../../components/fixed-popover'


const CONTAINER_ID = "nylas-popover-container";

function createContainer(id) {
  const element = document.createElement(id);
  document.body.appendChild(element);
  return element;
}

class PopoverStore extends NylasStore {

  constructor(containerId = CONTAINER_ID) {
    super()
    this.isOpen = false;
    this.container = createContainer(containerId);
    React.render(<span />, this.container);

    this.listenTo(Actions.openPopover, this.openPopover);
    this.listenTo(Actions.closePopover, this.closePopover);
  }

  isPopoverOpen = ()=> {
    return this.isOpen;
  };

  renderPopover = (child, props, callback)=> {
    const popover = (
      <FixedPopover {...props}>{child}</FixedPopover>
    );

    React.render(popover, this.container, ()=> {
      this.isOpen = true;
      this.trigger();
      callback();
    });
  };

  openPopover = (element, {originRect, direction, fallbackDirection, callback = ()=> {}})=> {
    const props = {
      direction,
      originRect,
      fallbackDirection,
    };

    if (this.isOpen) {
      this.closePopover(()=> {
        this.renderPopover(element, props, callback);
      })
    } else {
      this.renderPopover(element, props, callback);
    }
  };

  closePopover = (callback = ()=>{})=> {
    React.render(<span/>, this.container, ()=> {
      this.isOpen = false;
      this.trigger();
      callback();
    });
  };

}

export default new PopoverStore();
