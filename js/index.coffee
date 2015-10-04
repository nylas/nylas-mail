---
---

# startSequence()
# .then(step1)
# .then(step2)
# .then(step3)
# .then(step4)
# .then(step5)
#
# # show composer
# step1 = ->
#   startStep()
#   .then(focusClient)
#   .then(doReply)
#   .then(typeReply)
#   .then(addImage)
#   .then(sendEmail)
#
# step2 = ->
#   startStep()
#   .then(addAccount)
#   .then(focusPicker)
#   .then(selectAccount)
#   .then(swapModes)
#
# step3 = ->
#   startStep()
#   .then(openLabelPicker)
#   .then(typeLabel)
#   .then(applyLabel)
#
# step4 = ->
#   startStep()
#   .then(openInspectorPanel)
#   .then(typeCommand)
#   .then(activateExtension)
#
# step5 = ->
#   startStep()
#   .then(fadeClient)
#   .then(showCta)

animationContainerSize = [0,0]

window.step1 = ->

  animationContainerSize = [1136,823]
  setAnimationContainer()

  frames =
    "1-1": 2000
    "1-2": 2000
    "1-3": 2000
    "1-4": 2000
    "1-5": 2000
    "1-6": 2000

  i = 0
  frameImgs = _.map frames, (delay, frame) ->
    i++
    "<img id='#{frame}' src='images/#{frame}.png' style='z-index: #{i}'/>"

  $("#animation-container").html(frameImgs.join(''))
  $("#1-1").show()

  sequence = Promise.resolve()
  _.each frames, (delay, frame) ->
    sequence = sequence.then -> new Promise (resolve, reject) ->
      $("##{frame}").show()
      setTimeout(resolve, delay)
  sequence.then ->
    console.log("step 1 is done!")

setAnimationContainer = ->
  winW = $(window).width()
  winH = $(window).height() - $("#nav").height()
  [w,h] = animationContainerSize

  scaleW = 1 - (Math.min(winW - w, 0) / -w)
  scaleH = 1 - (Math.min(winH - h, 0) / -h)
  scale = Math.min(scaleW, scaleH)
  console.log scale
  $("#animation-container").css
    "width": "#{w}px"
    "height": "#{h}px"
    "margin-left": "-#{w/2}px"
    "-webkit-transform": "scale(#{scale})"
    "-moz-transform": "scale(#{scale})"
    "-ms-transform": "scale(#{scale})"
    "-o-transform": "scale(#{scale})"
    "transform": "scale(#{scale})"

# To allow for a fixed amount of bleed below the fold regardless of window
# size.
fixHeroHeight = ->
  Math.max(Math.min($("#hero")?.height($(window).height() + 200), 640), 1200)

# To ensure that our overflowing, dynamically sized screenshot pushes the
# remaining content down the correct ammount.
fixHeroMargin = ->
  marginBottom = Math.max(($("#main-screenshot").height() + ($("#main-screenshot").offset().top - $("#hero").offset().top)) - $("#hero").height(), 0)
  $("#hero").css(marginBottom: marginBottom)

# To ensure there's enough white-space between the watercolor images to
# let the hero text show through.
fixWatercolors = ->
  lCutoff = 0.55
  rCutoff = 0.6
  lWidth = $("#watercolor-left").width()
  rWidth = $("#watercolor-right").width()

  heroLeft = $("#hero-text").offset().left
  leftMove = Math.max(Math.min(heroLeft - (lWidth * lCutoff), 0), -lWidth * lCutoff)

  heroRight = $("#hero-text").offset().left + $("#hero-text").width()
  rightMove = Math.max(Math.min(heroRight - (rWidth * rCutoff), 0), -rWidth * rCutoff)

  $("#watercolor-left").css(left: leftMove)
  $("#watercolor-right").css(right: rightMove)

onResize = ->
  fixHeroHeight()
  # fixHeroMargin()
  fixWatercolors()
  setAnimationContainer()

window.onresize = onResize
window.onload = ->
  onResize()
  $("body").addClass("initial")
  $("#play-intro").on "click", ->
    $("body").addClass("step-0").removeClass("initial")
    step1()
