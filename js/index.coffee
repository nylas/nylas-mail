---
---

preparePage = ->

loadAssets = ->

fixHeroSize = ->
  Math.max(Math.min($("#hero")?.height($(window).height() + 200), 640), 1200)

fixNavMargin = ->
  marginBottom = Math.max(($("#main-screenshot").height() + ($("#main-screenshot").offset().top - $("#hero").offset().top)) - $("#hero").height(), 0)
  $("#hero").css(marginBottom: marginBottom)

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
  fixHeroSize()
  fixNavMargin()
  fixWatercolors()

window.onresize = onResize
window.onload = ->
  onResize()
