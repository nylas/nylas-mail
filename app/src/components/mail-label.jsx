import React from 'react';
import PropTypes from 'prop-types';
import RetinaImg from './retina-img';

export const LabelColorizer = {
  color(label) {
    return `hsl(${label.hue()}, 50%, 34%)`;
  },

  backgroundColor(label) {
    return `hsl(${label.hue()}, 62%, 87%)`;
  },

  backgroundColorDark(label) {
    return `hsl(${label.hue()}, 62%, 57%)`;
  },

  styles(label) {
    const styles = {
      color: LabelColorizer.color(label),
      backgroundColor: LabelColorizer.backgroundColor(label),
      boxShadow: `inset 0 0 1px hsl(${label.hue()}, 62%, 47%), inset 0 1px 1px rgba(255,255,255,0.5), 0 0.5px 0 rgba(255,255,255,0.5)`,
    };
    if (process.platform !== 'win32') {
      styles.backgroundImage = 'linear-gradient(rgba(255,255,255, 0.4), rgba(255,255,255,0))';
    }
    return styles;
  },
};

export class MailLabel extends React.Component {
  static propTypes = {
    label: PropTypes.object.isRequired,
    onRemove: PropTypes.func,
  };

  shouldComponentUpdate(nextProps) {
    if (nextProps.label.id === this.props.label.id) {
      return false;
    }
    return true;
  }

  _removable() {
    return this.props.onRemove && !this.props.label.isLockedCategory();
  }

  render() {
    let classname = 'mail-label';
    let content = this.props.label.displayName;

    let x = null;
    if (this._removable()) {
      classname += ' removable';
      content = <span className="inner">{content}</span>;
      x = (
        <RetinaImg
          className="x"
          name="label-x.png"
          style={{ backgroundColor: LabelColorizer.color(this.props.label) }}
          mode={RetinaImg.Mode.ContentIsMask}
          onClick={this.props.onRemove}
        />
      );
    }

    return (
      <div className={classname} style={LabelColorizer.styles(this.props.label)}>
        {content}
        {x}
      </div>
    );
  }
}
