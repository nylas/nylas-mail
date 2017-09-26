import { React, PropTypes, Utils } from 'mailspring-exports';
import { RetinaImg } from 'mailspring-component-kit';

export default class HeaderControls extends React.Component {
  static displayName = 'HeaderControls';

  static propTypes = {
    title: PropTypes.string,
    headerComponents: PropTypes.node,
    nextAction: PropTypes.func,
    prevAction: PropTypes.func,
  };

  static defaultProps = {
    headerComonents: false,
  };

  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.isEqualReact(nextProps, this.props) || !Utils.isEqualReact(nextState, this.state);
  }

  _renderNextAction() {
    if (!this.props.nextAction) {
      return false;
    }
    return (
      <button className="btn btn-icon next" ref="onNextAction" onClick={this.props.nextAction}>
        <RetinaImg name="ic-calendar-right-arrow.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }

  _renderPrevAction() {
    if (!this.props.prevAction) {
      return false;
    }
    return (
      <button className="btn btn-icon prev" ref="onPreviousAction" onClick={this.props.prevAction}>
        <RetinaImg name="ic-calendar-left-arrow.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }

  render() {
    return (
      <div className="header-controls">
        <div className="center-controls">
          {this._renderPrevAction()}
          <span className="title">{this.props.title}</span>
          {this._renderNextAction()}
        </div>
        {this.props.headerComponents}
      </div>
    );
  }
}
