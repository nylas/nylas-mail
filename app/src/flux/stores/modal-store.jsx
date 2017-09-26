import React from 'react';
import ReactDOM from 'react-dom';
import { Modal } from 'mailspring-component-kit';
import MailspringStore from 'mailspring-store';

import Actions from '../actions';

const CONTAINER_ID = 'nylas-modal-container';

function createContainer(id) {
  const element = document.createElement(id);
  document.body.insertBefore(element, document.body.children[0]);
  return element;
}

class ModalStore extends MailspringStore {
  constructor(containerId = CONTAINER_ID) {
    super();
    this.isOpen = false;
    this.container = createContainer(containerId);
    ReactDOM.render(<span />, this.container);

    this.listenTo(Actions.openModal, this.openModal);
    this.listenTo(Actions.closeModal, this.closeModal);
  }

  isModalOpen = () => {
    return this.isOpen;
  };

  renderModal = (child, props, callback) => {
    const modal = <Modal {...props}>{child}</Modal>;

    ReactDOM.render(modal, this.container, () => {
      this.isOpen = true;
      this.trigger();
      callback();
    });
  };

  openModal = ({ component, height, width }, callback = () => {}) => {
    const props = {
      height: height,
      width: width,
    };

    if (this.isOpen) {
      this.closeModal(() => {
        this.renderModal(component, props, callback);
      });
    } else {
      this.renderModal(component, props, callback);
    }
  };

  closeModal = (callback = () => {}) => {
    ReactDOM.render(<span />, this.container, () => {
      this.isOpen = false;
      this.trigger();
      callback();
    });
  };
}

export default new ModalStore();
