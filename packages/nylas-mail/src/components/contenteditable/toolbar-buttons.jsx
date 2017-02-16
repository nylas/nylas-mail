import React from 'react';
import {RetinaImg} from 'nylas-component-kit';

// This component renders buttons and is the default view in the
// FloatingToolbar.

// Extensions that implement `toolbarButtons` can get their buttons added
// in.

// The {EmphasisFormattingExtension} extension is an example of one that
// implements this spec.
export default class ToolbarButtons extends React.Component {
  static displayName = "ToolbarButtons"

  static propTypes = {
    // Declares what buttons should appear in the toolbar. An array of
    // config objects.
    buttonConfigs: React.PropTypes.array,
  }

  static defaultProps = {
    buttonConfigs: [],
  }

  render() {
    const buttons = this.props.buttonConfigs.map((config, i) => {
      const icon = ((config.iconUrl || '').length > 0) ? (
        <RetinaImg
          mode={RetinaImg.Mode.ContentIsMask}
          url="#{config.iconUrl}"
        />
      ) : null;

      return (
        <button
          className={`btn toolbar-btn ${config.className || ''}`}
          key={`btn-${i}`}
          onClick={config.onClick}
          title={`${config.tooltip}`}
        >
          {icon}
        </button>
      );
    });

    return (
      <div className="toolbar-buttons">
        {buttons}
      </div>
    );
  }
}
