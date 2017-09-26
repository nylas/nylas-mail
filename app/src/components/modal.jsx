import _ from 'underscore';
import React from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';
import Actions from '../flux/actions';
import RetinaImg from './retina-img';

class Modal extends React.Component {
  static propTypes = {
    className: PropTypes.string,
    children: PropTypes.element,
    height: PropTypes.number,
    width: PropTypes.number,
  };

  constructor(props) {
    super(props);
    this.state = {
      offset: 0,
      dimensions: {},
      animateClass: false,
    };
  }

  componentDidMount() {
    this._focusImportantElement();
    this._mounted = true;
    window.requestAnimationFrame(() => {
      if (!this._mounted) {
        return;
      }
      this.setState({ animateClass: true });
    });
  }

  componentWillUnmount() {
    this._mounted = false;
  }

  _focusImportantElement = () => {
    const modalNode = ReactDOM.findDOMNode(this);

    const focusable = modalNode.querySelectorAll('[tabIndex], input');
    const matches = _.sortBy(focusable, node => {
      if (node.tabIndex > 0) {
        return node.tabIndex;
      } else if (node.nodeName === 'INPUT') {
        return 1000000;
      }
      return 1000001;
    });
    if (matches[0]) {
      matches[0].focus();
    }
  };

  _computeModalStyles = (height, width) => {
    const modalStyle = {
      height: height,
      maxHeight: '95%',
      width: width,
      maxWidth: '95%',
      overflow: 'auto',
      position: 'absolute',
      backgroundColor: 'white',
      boxShadow: '0 10px 20px rgba(0,0,0,0.19), inset 0 0 1px rgba(0,0,0,0.5)',
      borderRadius: '5px',
    };
    return { modalStyle };
  };

  _onKeyDown = event => {
    if (event.key === 'Escape') {
      Actions.closeModal();
    }
  };

  render() {
    const { children, height, width } = this.props;
    const { modalStyle } = this._computeModalStyles(height, width);

    return (
      <div
        className={`modal-container ${this.state.animateClass && 'animate'}`}
        onKeyDown={this._onKeyDown}
        onClick={() => Actions.closeModal()}
      >
        <div className="modal" style={modalStyle} onClick={event => event.stopPropagation()}>
          <RetinaImg
            className="modal-close"
            style={{ width: '14', WebkitFilter: 'none', zIndex: '1', position: 'relative' }}
            name="modal-close.png"
            mode={RetinaImg.Mode.ContentDark}
            onClick={event => {
              event.stopPropagation();
              Actions.closeModal();
            }}
          />
          {children}
        </div>
      </div>
    );
  }
}

export default Modal;
