React = require 'react/addons'
{RetinaImg} = require 'nylas-component-kit'

# This component renders buttons and is the default view in the
# FloatingToolbar.
#
# Extensions that implement `toolbarButtons` can get their buttons added
# in.
#
# The {EmphasisFormattingExtension} extension is an example of one that
# implements this spec.
class ToolbarButtons extends React.Component
  @displayName = "ToolbarButtons"

  @propTypes:
    # Declares what buttons should appear in the toolbar. An array of
    # config objects.
    buttonConfigs: React.PropTypes.array

  @defaultProps:
    buttonConfigs: []

  render: ->
    <div className="toolbar-buttons">{@_renderToolbarButtons()}</div>

  _renderToolbarButtons: ->
    @props.buttonConfigs.map (config, i) ->
      if (config.iconUrl ? "").length > 0
        icon = <RetinaImg mode={RetinaImg.Mode.ContentIsMask}
                          url="#{config.iconUrl}" />
      else icon = ""

      <button className="btn toolbar-btn #{config.className ? ''}"
              key={"btn-#{i}"}
              onClick={config.onClick}
              title="#{config.tooltip}">{icon}</button>

module.exports = ToolbarButtons
