import {React} from 'nylas-exports';

export default class Modal extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      open: false,
      onOpen: props.onOpen || (() => {}),
      onClose: props.onClose || (() => {}),
    }
  }

  componentDidMount() {
    this.keydownHandler = (e) => {
      // Close modal on escape
      if (e.keyCode === 27) {
        this.close();
      }
    }
    document.addEventListener('keydown', this.keydownHandler);
  }

  componentWillUnmount() {
    document.removeEventListener('keydown', this.keydownHandler);
  }

  open() {
    this.setState({open: true});
    this.state.onOpen();
  }

  close() {
    this.setState({open: false});
    this.state.onClose();
  }

  // type can be 'button' or 'div'.
  // Always closes modal after the callback
  renderActionElem({title, type = 'button', action = () => {}, className = ""}) {
    const callback = (e) => {
      action(e);
      this.close();
    }
    if (type === 'button') {
      return (
        <button className={className} onClick={callback}>
          {title}
        </button>
      )
    }
    return (
      <div className={className} onClick={callback}>
        {title}
      </div>
    )
  }

  render() {
    const activator = (
      <div
        className={this.props.openLink.className}
        id={this.props.openLink.id}
        onClick={() => this.open.call(this)}
      >
        {this.props.openLink.text}
      </div>
    )
    if (!this.state.open) {
      return activator;
    }

    const actionElems = [];
    if (this.props.actionElems) {
      for (const config of this.props.actionElems) {
        actionElems.push(this.renderActionElem(config));
      }
    }

    return (
      <div>
        {activator}
        <div className="modal-bg">
          <div className={`${this.props.className || ''} modal`} id={this.props.id}>
            <div className="modal-close-wrapper">
              <div className="modal-close" onClick={() => this.close.call(this)} />
            </div>
            {this.props.children}
            {actionElems}
          </div>
        </div>
      </div>
    )
  }
}

Modal.propTypes = {
  openLink: React.PropTypes.object,
  className: React.PropTypes.string,
  id: React.PropTypes.string,
  onOpen: React.PropTypes.func,
  onClose: React.PropTypes.func,
  actionElems: React.PropTypes.arrayOf(React.PropTypes.object),
}
