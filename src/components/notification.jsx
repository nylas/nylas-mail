import React from 'react'
import RetinaImg from './retina-img';

export default class Notification extends React.Component {
  static containerRequired = false;

  static propTypes = {
    title: React.PropTypes.string,
    subtitle: React.PropTypes.string,
    subtitleAction: React.PropTypes.func,
    actions: React.PropTypes.array,
    icon: React.PropTypes.string,
    priority: React.PropTypes.string,
    isError: React.PropTypes.bool,
  }

  constructor() {
    super()
    this.state = {loadingActions: []}
  }

  componentDidMount() {
    this.mounted = true;
  }

  componentWillUnmount() {
    this.mounted = false;
  }

  _onClick(actionId, actionFn) {
    const result = actionFn();
    if (result instanceof Promise) {
      this.setState({
        loadingActions: this.state.loadingActions.concat([actionId]),
      })

      result.finally(() => {
        if (this.mounted) {
          this.setState({
            loadingActions: this.state.loadingActions.filter(f => f !== actionId),
          })
        }
      })
    }
  }

  render() {
    const actions = this.props.actions || [];
    const actionElems = actions.map((action, idx) => {
      const id = `action-${idx}`;
      let className = 'action'
      if (this.state.loadingActions.includes(id)) {
        className += ' loading'
      }
      return (
        <div
          key={id}
          id={id}
          className={className}
          onClick={() => this._onClick(id, action.fn)}
        >
          {action.label}
        </div>
      );
    })

    const {isError, priority, icon, title, subtitleAction, subtitle} = this.props;

    let iconEl = null;
    if (icon) {
      iconEl = <RetinaImg
        className="icon"
        name={icon}
        mode={RetinaImg.Mode.ContentPreserve}
      />
    }
    return (
      <div className={`notification${isError ? ' error' : ''}`} data-priority={priority}>
        <div className="title">
          {iconEl} {title} <br />
          <span
            className={`subtitle ${subtitleAction ? 'has-action' : ''}`}
            onClick={subtitleAction || (() => {})}
          >
            {subtitle}
          </span>
        </div>
        {actionElems.length > 0 ?
          <div className="actions-wrapper">{actionElems}</div> : null
        }
      </div>
    )
  }
}
