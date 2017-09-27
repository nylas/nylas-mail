import React from 'react';
import PropTypes from 'prop-types';
import RetinaImg from './retina-img';

export default class Notification extends React.Component {
  static containerRequired = false;

  static propTypes = {
    className: PropTypes.string,
    displayName: PropTypes.string,
    title: PropTypes.string,
    subtitle: PropTypes.string,
    subtitleAction: PropTypes.func,
    actions: PropTypes.array,
    icon: PropTypes.string,
    priority: PropTypes.string,
    isError: PropTypes.bool,
    isDismissable: PropTypes.bool,
    isPermanentlyDismissable: PropTypes.bool,
  };

  static defaultProps = {
    className: '',
  };

  constructor(props) {
    super(props);
    this.state = {
      loadingActions: [],
      isDismissed: this._isDismissed(),
    };
  }

  componentDidMount() {
    this.mounted = true;
  }

  componentWillUnmount() {
    this.mounted = false;
  }

  _isDismissed() {
    if (this.props.isPermanentlyDismissable) {
      return this._numAsks() >= 5;
    }
    return false;
  }

  _numAsks() {
    if (!AppEnv.savedState.dismissedNotificationAsks) {
      AppEnv.savedState.dismissedNotificationAsks = {};
    }
    if (!AppEnv.savedState.dismissedNotificationAsks[this.props.displayName]) {
      AppEnv.savedState.dismissedNotificationAsks[this.props.displayName] = 0;
    }
    return AppEnv.savedState.dismissedNotificationAsks[this.props.displayName];
  }

  async _onClick(event, actionId, actionFn) {
    const result = actionFn(event);
    if (result instanceof Promise) {
      this.setState({
        loadingActions: this.state.loadingActions.concat([actionId]),
      });

      try {
        await result;
      } catch (err) {
        // ignored
      }

      if (this.mounted) {
        this.setState({
          loadingActions: this.state.loadingActions.filter(f => f !== actionId),
        });
      }
    }
  }

  _subtitle() {
    if (this.props.isPermanentlyDismissable && this._numAsks() >= 1) {
      return "Don't show this again";
    }
    return this.props.subtitle;
  }

  _subtitleAction = () => {
    if (this.props.isPermanentlyDismissable && this._numAsks() >= 1) {
      return () => {
        AppEnv.savedState.dismissedNotificationAsks[this.props.displayName] = 5;
        this.setState({ isDismissed: true });
      };
    }
    return this.props.subtitleAction;
  };

  render() {
    if (this.state.isDismissed) return <span />;

    const actions = this.props.actions || [];

    if (this.props.isDismissable) {
      actions.push({
        label: 'Dismiss',
        fn: () => {
          AppEnv.savedState.dismissedNotificationAsks[this.props.displayName] = this._numAsks() + 1;
          this.setState({ isDismissed: true });
        },
      });
    }

    const actionElems = actions.map((action, idx) => {
      const id = `action-${idx}`;
      let className = 'action';
      if (this.state.loadingActions.includes(id)) {
        className += ' loading';
      }
      return (
        <div
          key={id}
          id={id}
          className={className}
          onClick={e => this._onClick(e, id, action.fn)}
          {...action.props}
        >
          {action.label}
        </div>
      );
    });

    const { className, isError, priority, icon, title } = this.props;
    const subtitle = this._subtitle();
    const subtitleAction = this._subtitleAction();

    let iconEl = null;
    if (icon) {
      iconEl = <RetinaImg className="icon" name={icon} mode={RetinaImg.Mode.ContentPreserve} />;
    }
    return (
      <div
        className={`notification${isError ? ' error' : ''} ${className}`}
        data-priority={priority}
      >
        <div className="title">
          {iconEl} {title} <br />
          <span
            className={`subtitle ${subtitleAction ? 'has-action' : ''}`}
            onClick={subtitleAction}
          >
            {subtitle}
          </span>
        </div>
        {actionElems.length > 0 ? <div className="actions-wrapper">{actionElems}</div> : null}
      </div>
    );
  }
}
