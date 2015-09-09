React = require 'react'
_ = require 'underscore'
{RetinaImg, Flexbox} = require 'nylas-component-kit'

class AppearanceModeOption extends React.Component
  @propTypes:
    mode: React.PropTypes.string.isRequired
    active: React.PropTypes.bool
    onClick: React.PropTypes.func

  constructor: (@props) ->

  render: =>
    classname = "appearance-mode"
    classname += " active" if @props.active
    <div className={classname} onClick={@props.onClick}>
      <RetinaImg name={"appearance-mode-#{@props.mode}.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      <div>{@props.mode} View</div>
    </div>

class PreferencesAppearance extends React.Component
  @displayName: 'PreferencesAppearance'
  @propTypes:
    config: React.PropTypes.object

  render: =>
    <div className="container-appearance">
      <div className="section">
        <div className="section-header">
          Layout and theme:
        </div>
        <div className="section-body section-appearance">
          <Flexbox direction="row" style={alignItems: "center"}>
            {['list', 'split'].map (mode) =>
              <AppearanceModeOption
                mode={mode} key={mode}
                active={@props.config.get('core.workspace.mode') is mode}
                onClick={ => @props.config.set('core.workspace.mode', mode)} />
            }
          </Flexbox>

          <div className="section-header">
            <input type="checkbox"
                   id="dark"
                   checked={@props.config.contains('core.themes','ui-dark')}
                   onChange={ => @props.config.toggleContains('core.themes', 'ui-dark')}
                   />
            <label htmlFor="dark">Use dark color scheme</label>
          </div>
        </div>
      </div>
    </div>

module.exports = PreferencesAppearance
