React = require 'react'
_ = require 'underscore'
{RetinaImg, Flexbox} = require 'nylas-component-kit'

class PreferencesNotifications extends React.Component
  @displayName: 'PreferencesNotifications'

  @propTypes:
    config: React.PropTypes.object.isRequired

  render: =>
    <div className="container-notifications">
      <div className="section">
        <div className="section-header">
          Notifications:
        </div>
        <div className="section-body">
          <p className="platform-darwin-only">
            <input type="checkbox"
                   id="core.showUnreadBadge"
                   checked={@props.config.get('core.showUnreadBadge')}
                   onChange={ => @props.config.toggle('core.showUnreadBadge')}/>
            <label htmlFor="core.showUnreadBadge">Badge dock icon with unread message count</label>
          </p>
          <p>
            <input type="checkbox"
                   id="core.notifications.enabled"
                   checked={@props.config.get('core.notifications.enabled')}
                   onChange={ => @props.config.toggle('core.notifications.enabled')}/>
            <label htmlFor="core.notifications.enabled">Show notifications for new unread messages</label>
          </p>
        </div>
      </div>

      <div className="section-header">
        Sounds:
      </div>
      <div className="section-body">
        <p>
          <input type="checkbox"
                 id="core.notifications.sounds"
                 checked={@props.config.get('core.notifications.sounds')}
                 onChange={ => @props.config.toggle('core.notifications.sounds')}/>
          <label htmlFor="core.notifications.sounds">Play sound when receiving new mail</label>
        </p>
        <p>
          <input type="checkbox"
                 id="core.sending.sounds"
                 checked={@props.config.get('core.sending.sounds')}
                 onChange={ => @props.config.toggle('core.sending.sounds')}/>
          <label htmlFor="core.sending.sounds">Play sound when a message is sent</label>
        </p>
      </div>
    </div>

module.exports = PreferencesNotifications
