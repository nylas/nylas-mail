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
    <Flexbox className="preference-header" direction="row" style={alignItems: "center"}>
      { @props.tabs.map (tab) =>
        classname = "preference-header-item"
        classname += " active" if tab is @props.activeTab

        <div className={classname} onClick={ => @props.changeActiveTab(tab) } key={tab.name}>
          <div className="phi-container">
            <div className="icon">
              <RetinaImg mode={RetinaImg.Mode.ContentPreserve} name={tab.icon} />
            </div>
            <div className="name">
              {tab.name}
            </div>
          </div>
        </div>
      }
      <div key="space" className="preference-header-item-spacer"></div>
    </Flexbox>


module.exports = PreferencesHeader
