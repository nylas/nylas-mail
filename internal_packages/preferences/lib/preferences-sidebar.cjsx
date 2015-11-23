React = require 'react'
_ = require 'underscore'
{RetinaImg, Flexbox} = require 'nylas-component-kit'
{Actions} = require 'nylas-exports'

class PreferencesSidebar extends React.Component
  @displayName: 'PreferencesSidebar'

  @propTypes:
    sections: React.PropTypes.array.isRequired
    activeSectionId: React.PropTypes.string

  render: =>
    <div className="preferences-sidebar">
      { @props.sections.map ({sectionId, displayName}) =>
        classname = "item"
        classname += " active" if sectionId is @props.activeSectionId

        <div key={sectionId}
             className={classname}
             onClick={ => Actions.switchPreferencesSection(sectionId) }>
          <div className="name">
            {displayName}
          </div>
        </div>
      }
    </div>


module.exports = PreferencesSidebar
