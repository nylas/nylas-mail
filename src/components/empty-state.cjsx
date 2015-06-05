_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
RetinaImg = require './retina-img'

EmptyMessages = [{
  "body":"The pessimist complains about the wind.\nThe optimist expects it to change.\nThe realist adjusts the sails."
  "byline": "- William Arthur Ward"
},{
  "body":"The best and most beautiful things in the world cannot be seen or even touched - they must be felt with the heart."
  "byline": "- Hellen Keller"
},{
  "body":"Believe you can and you're halfway there."
  "byline": "- Theodore Roosevelt"
},{
  "body":"Don't judge each day by the harvest you reap but by the seeds that you plant."
  "byline": "- Robert Louis Stevenson"
}]

class EmptyState extends React.Component
  @displayName = 'EmptyState'
  @propTypes =
    visible: React.PropTypes.bool.isRequired

  constructor: (@props) ->
    @state =
      active: false

  componentDidUpdate: ->
    if @props.visible and not @state.active
      # Pick a random quote using the day as a seed. I know not all months have
      # 31 days - this is good enough to generate one quote a day at random!
      d = new Date()
      r = d.getDate() + d.getMonth() * 31
      message = EmptyMessages[r % EmptyMessages.length]
      @setState(active:true, message: message)

  componentWillReceiveProps: (newProps) ->
    if newProps.visible is false
      @setState(active:false)

  render: ->
    classes = classNames
      'empty-state': true
      'visible': @props.visible
      'active': @state.active

    <div className={classes}>
      <div>
        <div className="message">
          {@state.message?.body}
          <div className="byline">
            {@state.message?.byline}
          </div>
        </div>
        <RetinaImg mode={RetinaImg.Mode.ContentLight} name="blank-bottom-left.png" className="bottom-left"/>
        <RetinaImg mode={RetinaImg.Mode.ContentLight} name="blank-top-left.png" className="top-left"/>
        <RetinaImg mode={RetinaImg.Mode.ContentLight} name="blank-bottom-right.png" className="bottom-right"/>
        <RetinaImg mode={RetinaImg.Mode.ContentLight} name="blank-top-right.png" className="top-right"/>
      </div>
    </div>


module.exports = EmptyState
