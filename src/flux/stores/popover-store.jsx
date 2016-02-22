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

    this.listenTo(Actions.openPopover, this.onOpenPopover);
    this.listenTo(Actions.closePopover, this.onClosePopover);
  }

  isPopoverOpen = ()=> {
    return this.isOpen;
  };

  onOpenPopover = (element, originRect, direction)=> {
    const popover = (
      <FixedPopover
        showing
        originRect={originRect}
        direction={direction}>
        {element}
      </FixedPopover>
    )
    React.render(popover, this.container, ()=> {
      this.isOpen = true;
      this.trigger();
    })
  };

  onClosePopover = ()=> {
    const popover = <FixedPopover showing={false} />;
    React.render(popover, this.container, ()=> {
      this.isOpen = false;
      this.trigger();
    })
  };

}

export default new PopoverStore();
