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
  fixHeroMargin()
  fixWatercolors()

window.onresize = onResize
window.onload = ->
  onResize()
