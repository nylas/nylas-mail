import React from 'react';
import NylasStore from 'nylas-store'
import Actions from '../actions'
import {FixedPopover} from 'nylas-component-kit';


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
    React.render(<FixedPopover showing={false} />, this.container);

    this.listenTo(Actions.openPopover, this.openPopover);
    this.listenTo(Actions.closePopover, this.closePopover);
  }

  isPopoverOpen = ()=> {
    return this.isOpen;
  };

  renderPopover = (popover, isOpen, callback)=> {
    React.render(popover, this.container, ()=> {
      this.isOpen = isOpen;
      this.trigger();
      callback()
    })
  };

  openPopover = (element, originRect, direction, callback = ()=> {})=> {
    const popover = (
      <FixedPopover
        showing
        originRect={originRect}
        direction={direction}>
        {element}
      </FixedPopover>
    );

    if (this.isOpen) {
      this.closePopover(()=> {
        this.renderPopover(popover, true, callback);
      })
    } else {
      this.renderPopover(popover, true, callback);
    }
  };

  closePopover = (callback = ()=>{})=> {
    const popover = <FixedPopover showing={false} />;
    this.renderPopover(popover, false, callback);
  };

}

export default new PopoverStore();
