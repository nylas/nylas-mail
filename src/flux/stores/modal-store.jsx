import React from 'react';
import NylasStore from 'nylas-store'
import Actions from '../actions'
import {Modal} from 'nylas-component-kit';


const CONTAINER_ID = "nylas-modal-container";

function createContainer(id) {
  const element = document.createElement(id);
  document.body.appendChild(element);
  return element;
}

class ModalStore extends NylasStore {

  constructor(containerId = CONTAINER_ID) {
    super()
    this.isOpen = false;
    this.container = createContainer(containerId);
    React.render(<span />, this.container);

    this.listenTo(Actions.openModal, this.openModal);
    this.listenTo(Actions.closeModal, this.closeModal);
  }

  isModalOpen = ()=> {
    return this.isOpen;
  };

  renderModal = (child, props, callback)=> {
    const modal = (
      <Modal {...props}>{child}</Modal>
    );

    React.render(modal, this.container, ()=> {
      this.isOpen = true;
      this.trigger();
      callback();
    });
  };

  openModal = (component, height, width, callback = ()=> {})=> {
    const props = {
      height: height,
      width: width,
    };

    if (this.isOpen) {
      this.closeModal(()=> {
        this.renderModal(component, props, callback);
      })
    } else {
      this.renderModal(component, props, callback);
    }
  };

  closeModal = (callback = ()=>{})=> {
    React.render(<span/>, this.container, ()=> {
      this.isOpen = false;
      this.trigger();
      callback();
    });
  };

}

export default new ModalStore();
