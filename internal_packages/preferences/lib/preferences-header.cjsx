React = require 'react'
_ = require 'underscore'
{RetinaImg, Flexbox} = require 'nylas-component-kit'

class PreferencesHeader extends React.Component
  @displayName: 'PreferencesHeader'

  @propTypes:
    tabs: React.PropTypes.array.isRequired
    changeActiveTab: React.PropTypes.func.isRequired
    activeTab: React.PropTypes.object

  render: =>
    if process.platform is "win32"
      imgMode = RetinaImg.Mode.ContentIsMask
    else
      imgMode = RetinaImg.Mode.ContentPreserve

    <div className="preference-header">
      { @props.tabs.map (sectionConfig) =>
        classname = "preference-header-item"
        classname += " active" if sectionConfig is @props.activeTab

        <div className={classname} onClick={ => @props.changeActiveTab(sectionConfig) } key={sectionConfig.sectionId}>
          <div className="phi-container">
            <div className="icon">
              <RetinaImg mode={imgMode} {...sectionConfig.nameOrUrl()} />
            </div>
            <div className="name">
              {sectionConfig.displayName}
            </div>
          </div>
        </div>
      }
    </div>


module.exports = PreferencesHeader
