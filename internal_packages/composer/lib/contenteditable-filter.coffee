class ContenteditableFilter
  # Gets called immediately before insert the HTML into the DOM. This is
  # useful for modifying what the user sees compared to the data we're
  # storing.
  beforeDisplay: ->

  # Gets called just after the content has changed but just before we save
  # out the new HTML. The inverse of `beforeDisplay`
  afterDisplay: ->

module.exports = ContenteditableFilter
