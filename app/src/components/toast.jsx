import React, {Component, PropTypes} from 'react'
import ReactCSSTransitionGroup from 'react-addons-css-transition-group'


class Toast extends Component {
  static displayName = 'Toast'

  static propTypes = {
    className: PropTypes.string,
    visible: PropTypes.bool,
    visibleDuration: PropTypes.number,
    onDidHide: PropTypes.func,
  }

  static defaultProps = {
    visible: false,
    visibleDuration: 3000,
    onDidHide: () => {},
  }

  constructor(props) {
    super(props)
    this._timeout = null
    this._mounted = false
    this.state = {
      visible: props.visible,
    }
  }

  componentDidMount() {
    this._mounted = true
    this._ensureTimeout()
  }

  componentWillReceiveProps(nextProps) {
    this.setState({visible: nextProps.visible})
  }

  componentDidUpdate() {
    this._ensureTimeout()
  }

  componentWillUnmount() {
    const {onDidHide} = this.props
    this._mounted = false
    onDidHide()
  }

  _clearTimeout() {
    clearTimeout(this._timeout)
    this._timeout = null
  }

  _ensureTimeout() {
    const {visible} = this.state
    const {visibleDuration, onDidHide} = this.props
    this._clearTimeout()
    if (visible) {
      if (visibleDuration == null) { return }
      this._timeout = setTimeout(() => {
        this._mounted = false
        this.setState({visible: false}, onDidHide)
      }, visibleDuration)
    }
  }

  _onMouseEnter = () => {
    this._clearTimeout()
  }

  _onMouseLeave = () => {
    this._ensureTimeout()
  }

  render() {
    const {className, children} = this.props
    const {visible} = this.state
    return (
      <ReactCSSTransitionGroup
        className={`nylas-toast ${className}`}
        transitionLeaveTimeout={150}
        transitionEnterTimeout={150}
        transitionName="nylas-toast-item"
      >
        {visible ?
          <div
            className="nylas-toast-wrap"
            onMouseEnter={this._onMouseEnter}
            onMouseLeave={this._onMouseLeave}
          >
            {children}
          </div> :
          null
        }
      </ReactCSSTransitionGroup>
    )
  }
}

export default Toast
