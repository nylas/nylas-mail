---
---

animationContainerSize = [0,0]

moveCursor = (start, end) ->
  try
    selection = document.getSelection?()
    return unless selection
    child = selection.anchorNode?.childNodes?[0]
    if child
      node = child
    else
      node = selection.anchorNode
    return unless node
    if selection.setBaseAndExtent
      selection.setBaseAndExtent(node, start, node, end)
    else if Range
      range = new Range
      start = Math.min(node.length ? 1000, start)
      end = Math.min(node.lengty ? 1000, end)
      range.setStart(node, start)
      range.setEnd(node, end)
      selection.removeAllRanges?()
      selection.addRange?(range)
    else return
  catch e
    console.error e
  return

typeMe = (str, parent, {top, left}) -> new Promise (resolve, reject) ->
  el = $("<div contenteditable=true id='editable'/>")
  parent.append(el)
  el.css {top, left}
  el.focus()
  sequence = Promise.resolve()
  accumulator = ""
  setTimeout ->
    _.each str.split(''), (char, i) ->
      delay = Math.random() * 120 + 10
      sequence = sequence.then -> new Promise (resolve, reject) ->
        accumulator += char
        el.html(accumulator)
        selection = document.getSelection()
        moveCursor(accumulator.length, accumulator.length)
        setTimeout(resolve, delay)
    sequence.then ->
      resolve()
  , 1500

addFramesToAnimationContainer = (frames, {wrapId}) ->
  i = 0
  frameImgs = _.map frames, ({delay, callback}, frame) ->
    i++
    "<img id='#{frame}' src='{{ site.baseurl }}/images/#{frame}.png' style='z-index: #{i}'/>"
  frameImgs = frameImgs.join('')
  $("#animation-container").append("<div id='#{wrapId}'>#{frameImgs}</div>")
  return

runFrames = (frames) ->
  sequence = Promise.resolve()
  _.each frames, ({delay, callback}, frame) ->
    sequence = sequence.then -> new Promise (resolve, reject) ->
      $("##{frame}").show()
      if callback then callback(delay, resolve)
      else setTimeout(resolve, delay)
  return sequence

window.screencastSequence = ->

  # Need to know the dimensions of the images used in step 1
  screenHeight = 823
  bufferHeight = 100
  animationContainerSize = [1136,screenHeight+bufferHeight]
  positionAnimationContainer()

  typeInReply = (delay, resolve) ->
    coords =
      top: 449
      left: 608
    typeMe("Wow! Iceland looks awesome.", $("#step1"), coords)
    .then ->
      setTimeout ->
        moveCursor(19, 26)
        $("#1-4-hovering-toolbar").addClass("pop-in")
        resolve()
      , delay

  markBold = (delay, resolve) ->
    setTimeout ->
      $("#editable").html("Wow! Iceland looks <strong>awesome</strong>.")
      len = $("#editable").html().length
      moveCursor(len, len)
      $("#1-4-hovering-toolbar").removeClass("pop-in").addClass("pop-out")
      setTimeout(resolve, 2*delay)
    , delay

  adjustTypedText = (delay, resolve) ->
    try
      if Audio
        a = new Audio
        a.src = "{{ site.baseurl }}/images/send.ogg"
        a.autoplay = true
        $("#step1").append(a)
        a.play?()
    catch
      console.log "Audio not supported"
    $("#editable").removeAttr("contenteditable")
    $("#editable").css top: 568, left: 607
    setTimeout(resolve, delay)

  showMultiSelectToolbar = (delay, resolve) ->
    $toolbarWrap = $("<div id='toolbar-wrap'><img id='toolbar' class='slide-in-from-top' src='{{ site.baseurl }}/images/2-topbar.png' style='display:block; position: relative' /></div>")
    $("#step2").append($toolbarWrap)
    $toolbarWrap.css
      "display": "block"
      "position": "absolute"
      "overflow": "hidden"
      "z-index": "7"
      "left": "266px"
      "top": "32px"
    setTimeout(resolve, delay)

  postArchiveUpdate = (delay, resolve) ->
    $("#toolbar").removeClass("slide-in-from-top").addClass("slide-out-to-top")
    $("#2-8-hover-archive").hide()
    $("#2-9-depress-archive").hide()
    $("#2-7-select-row-4").hide()
    $("#2-4-select-row-2").hide()
    setTimeout(resolve, delay)

  frames =
    step1:
      "1-1-initial-outlook-base": {delay: 3000}
      "1-2-depress-reply": {delay: 250}
      "1-3-show-reply": {delay: 500, callback: typeInReply}
      "1-4-hovering-toolbar": {delay: 1000, callback: markBold}
      "1-5-depress-send": {delay: 300}
      "1-6-sent-message": {delay: 2000, callback: adjustTypedText}
    step2:
      "2-1-initial-gmail-base": {delay: 2000}
      "2-2-select-row-1": {delay: 400, callback: showMultiSelectToolbar}
      "2-3-cursor-to-row-2": {delay: 400}
      "2-4-select-row-2": {delay: 400}
      "2-5-cursor-to-row-3": {delay: 250}
      "2-6-cursor-to-row-4": {delay: 400}
      "2-7-select-row-4": {delay: 800}
      "2-8-hover-archive": {delay: 1000}
      "2-9-depress-archive": {delay: 250}
      "2-10-updated-threadlist": {delay: 2000, callback: postArchiveUpdate}

  addFramesToAnimationContainer(frames.step1, wrapId: "step1")
  addFramesToAnimationContainer(frames.step2, wrapId: "step2")

  $("##{_.keys(frames.step1)[0]}").show()

  $("#step1").append("<h4>N1 is a brand new email client built by Nylas.</h4>")
  return runFrames(frames.step1).then -> new Promise (resolve, reject) ->
    $("#step2").append("<h4>It feels familiar, especially for Gmail users.</h4>")
    $("#step1").addClass("slide-out")
    $("#step2").addClass("slide-in")
    $("##{_.keys(frames.step2)[0]}").show()
    $("#step1").on "animationend", ->
      $("#step1").off "animationend"
      $("#step1").remove()
      runFrames(frames.step2).then ->
        $("#step2").removeClass("slide-in").addClass("slide-out")
        $("#step2").on "animationend", ->
          $("#step2").remove()
          return resolve()

window.providerSequence = ->
  new Promise (resolve, reject) ->
    providers = [
      "outlook"
      "exchange"
      "gmail"
      "icloud"
      "yahoo"
    ]
    imgs = providers.map (provider, i) ->
      "<img id='#{provider}' class='provider-img p-#{i}' src='{{ site.baseurl }}/images/providers/#{provider}@2x.png'/>"
    .join('')
    os = "<img id='os-image' class='os-image' src='{{ site.baseurl }}/images/platforms.png'>"
    header = "<h4>N1 is universal and cross-platform.</h4>"

    $("#animation-container").html("<div id='provider-wrap'>#{header}#{imgs}<br/>#{os}</div>")
    setTimeout ->
      $("#provider-wrap").addClass("provider-out")
      $("#provider-wrap .p-4").on "animationend", ->
        $("#provider-wrap").remove()
        resolve()
    , 4000

window.pluginsSequence = ->
  new Promise (resolve, reject) ->
    $("#animation-container").html('<div id="window-container" class="window"><div class="static-screenshot"></div></div><h4 id="plugins-title">N1 also supports rich plugins to add new features.</h4>')
    almostDone = ->
      $("#window-container").addClass("add-shadow")
    runPluginsSequence(resolve, almostDone)

positionAnimationContainer = ->
  winW = $(window).width()
  winH = $(window).height() - $("#nav").height()
  [w,h] = animationContainerSize

  leftoverH = Math.max(winH - h - 80, 0)

  scaleW = 1 - (Math.min(winW - w, 0) / -w)
  scaleH = 1 - (Math.min(winH - h, 0) / -h)
  scale = Math.min(scaleW, scaleH)
  $("#animation-container").css
    "width": "#{w}px"
    "height": "#{h}px"
    "margin-left": "-#{w/2}px"
    "margin-top": "#{leftoverH/2}px"
    "-webkit-transform": "scale(#{scale})"
    "-moz-transform": "scale(#{scale})"
    "-ms-transform": "scale(#{scale})"
    "-o-transform": "scale(#{scale})"
    "transform": "scale(#{scale})"

# To allow for a fixed amount of bleed below the fold regardless of window
# size.
fixHeroHeight = ->
  $("#hero")?.height(Math.max($(window).height() + 200, 640))

# To ensure that our overflowing, dynamically sized screenshot pushes the
# remaining content down the correct ammount.
fixHeroMargin = ->
  marginBottom = Math.max(($("#main-screenshot").height() + ($("#main-screenshot").offset().top - $("#hero").offset().top)) - $("#hero").height(), 0)
  $("#hero").css(marginBottom: marginBottom)

# To ensure there's enough white-space between the watercolor images to
# let the hero text show through.
fixWatercolors = ->

  leftSolid = 708/800
  leftTrans = 196/800
  rightSolid = 295/800
  rightTrans = 433/800

  hh = $("#hero").height()
  hw = $("#hero").width()
  leftSolidWidth = hh * leftSolid
  leftTransWidth = hh * leftTrans
  rightSolidWidth = hh * rightSolid
  rightTransWidth = hh * rightTrans
  $("#left-solid").height(hh).width(leftSolidWidth)
  $("#left-trans").height(hh).width(leftTransWidth)
  $("#right-solid").height(hh).width(rightSolidWidth)
  $("#right-trans").height(hh).width(rightTransWidth)

  heroLeft = $("#hero-text").offset().left
  heroRight = $("#hero-text").offset().left + $("#hero-text").width()

  lw = (leftSolidWidth + leftTransWidth)
  rw = (rightSolidWidth + rightTransWidth)

  overlapLeft = 120
  overlapRight = 300
  shiftLeft = Math.min(heroLeft - lw + overlapLeft, 0)
  shiftRight = Math.min((hw - heroRight) - rw + overlapRight, 0)

  $("#watercolor-left").css(left: shiftLeft)
  $("#watercolor-right").css(right: shiftRight)

fixStaticClientImages = ->
  overhang = 70
  padding = 40
  nominalScreenshot = 1280
  nominalComposer = 615
  innerWidth = $("#static-client-images").innerWidth() - padding - overhang

  if window.experiments.disableAnimation
    heroOverhangHeight = 200
    $("#static-client-images").css
      "margin-top": -1 * (heroOverhangHeight + $(window).height() * 0.2)

  scale = Math.min(1 - (nominalScreenshot - innerWidth) / nominalScreenshot, 1)
  $(".static-screenshot, #static-screenshot-wrap").width(nominalScreenshot * scale)
  $(".static-composer").width(nominalComposer * scale)
  $wc = $("#window-container")
  if $wc.length > 0
    $wc.width(nominalScreenshot * scale)

    $spacer = $("#window-container-after-spacer")
    $spacer.css "margin-top": 0

    bot = $wc.offset().top + $wc.height()
    margin = bot - ($spacer.offset().top - 100)

    $spacer.css "margin-top": margin

    # if $wc.hasClass("free-falling")
    #   $("#window-container-after-spacer").css
    #     "margin-top": $wc.height() + 100
    # else
    #   $("#window-container-after-spacer").css
    #     "margin-top": 50
  else
    $("#window-container-after-spacer").css
      "margin-top": 50

onResize = ->
  fixHeroHeight()
  # fixHeroMargin()
  fixWatercolors()
  positionAnimationContainer()
  fixStaticClientImages()

window.experiments = {}

window.onresize = onResize
$ ->
  onResize()
  $("body").addClass("initial")

  animationPlaying = false
  $("#play-intro, .hero-text").on "click", _.debounce ->
    return if window.experiments.disableAnimation
    return if animationPlaying
    animationPlaying = true
    ga?("track", "event", "N1", "intro", "start")
    fixHeroHeight()
    $("body").removeClass("finished").removeClass("start-animation")

    $("#hero-text").on "animationend", ->
      $("#hero-text").off "animationend"
      $("#hero-text").hide()

    $wc = $("#window-container")
    if $wc.length > 0
      $wc.addClass("fade-out")
      $wc.on "animationend", -> $wc.remove()

    $("#plugins-title").remove()
    $("#window-container-after-spacer").removeClass("free-falling")
    $("#static-client-images").css
      "margin-top": "-180px"
    $("body").addClass("start-animation").removeClass("initial")
    screencastSequence()
    .then(providerSequence)
    .then(pluginsSequence)
    .then =>
      $wc = $("#window-container")
      $wc.addClass("fade-out")
      $wc.on "animationend", -> $wc.remove()
      $("body").addClass("finished")
      $("#hero-text").show()
      $("#static-client-images").css
        "margin-top": "-320px"
      animationPlaying = false

      # $("#static-client-images").height($("#hero").height() - 250)

      # a = $('#window-container')
      # a.append("<img src='{{ site.baseurl }}/images/1-initial-outlook-base-noshadow.png' style='width:100%' />")
      # a.children('.part').remove()
      # a.css({
      #   width: a[0].getBoundingClientRect().width,
      #   height: a[0].getBoundingClientRect().height
      # })
      # a.addClass("free-falling")
      # a.append($('<img class="static-composer" src="{{ site.baseurl }}/images/composer-no-shadow.png" class="composer">'))
      # setTimeout =>
      #   a.addClass("finished")
      #   a.css({ width: "", height: "" })
      #   fixStaticClientImages()
      # , 1
      # $("#hero").parent().append(a)
      # $("#window-container-after-spacer").addClass("free-falling")

      $('#play-intro').html('<div class="triangle"></div>Replay Intro</div>')

      setTimeout ->
        fixStaticClientImages()
      , 2200
  , 100

window.onload = ->
  onResize()

console.log("%cWe love your curiosity! Let us know what other easter eggs you find. 😊 We're always looking for extraordinary people. Check out the jobs page or give me a ping at evan@nylas.com if you're interested in learning more about some of the big challenges we're tackling", "font-size: 16px;font-family:FaktPro, sans-serif;line-height:1.7")
