import React from 'react';
import ReactDOM from 'react-dom';

/**
Public: Images are supposed to by default show a ghost image when dragging and
dropping. Unfortunately this does not work in Electron. Since we're a
desktop app we don't want all images draggable, but we do want some (like
attachments) to be able to be dragged away with a preview image.
*/
export default class DraggableImg extends React.Component {
  static displayName = 'DraggableImg';

  _onDragStart = (event) => {
    const img = ReactDOM.findDOMNode(this.refs.img);
    const rect = img.getBoundingClientRect();
    const y = event.clientY - rect.top;
    const x = event.clientX - rect.left;
    event.dataTransfer.setDragImage(img, x, y);
    return;
  }

  render() {
    return (
      <img
        ref="img"
        draggable="true"
        onDragStart={this._onDragStart}
        role="presentation"
        {...this.props}
      />
    );
  }
}
