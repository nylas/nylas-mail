ThreadDragImage = document.createElement("img")
ThreadDragImage.src = """data:image/png;base64,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"""

DragCanvas = document.createElement("canvas")
DragCanvas.style.position = "absolute"
document.body.appendChild(DragCanvas)

SystemTrayCanvas = document.createElement("canvas")

CanvasUtils =
  roundRect: (ctx, x, y, width, height, radius = 5, fill, stroke = true) ->
    ctx.beginPath()
    ctx.moveTo(x + radius, y)
    ctx.lineTo(x + width - radius, y)
    ctx.quadraticCurveTo(x + width, y, x + width, y + radius)
    ctx.lineTo(x + width, y + height - radius)
    ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height)
    ctx.lineTo(x + radius, y + height)
    ctx.quadraticCurveTo(x, y + height, x, y + height - radius)
    ctx.lineTo(x, y + radius)
    ctx.quadraticCurveTo(x, y, x + radius, y)
    ctx.closePath()
    ctx.stroke() if stroke
    ctx.fill() if fill

  canvasWithThreadDragImage: (count) ->
    canvas = DragCanvas

    # Make sure the canvas has a 2x pixel density on retina displays
    scale = window.devicePixelRatio
    canvas.width = 58 * scale
    canvas.height = 55 * scale
    canvas.style.width = "58px"
    canvas.style.height = "55px"

    # necessary for setDragImage to work
    ctx = canvas.getContext('2d')

    # mail background image
    if count > 1
      ctx.rotate(-20*Math.PI/180)
      ctx.drawImage(ThreadDragImage, -10*scale, 2*scale, 48*scale, 48*scale)
      ctx.rotate(20*Math.PI/180)
    ctx.drawImage(ThreadDragImage, 0, 0, 48*scale, 48*scale)

    # count bubble
    dotGradient = ctx.createLinearGradient(0, 0, 0, 15 * scale)
    dotGradient.addColorStop(0, "rgb(116, 124, 143)")
    dotGradient.addColorStop(1, "rgb(67, 77, 104)")
    ctx.strokeStyle = "rgba(39, 48, 68, 0.6)"
    ctx.lineWidth = 1
    ctx.fillStyle = dotGradient

    textX = 49
    text = "#{count}"

    if (count < 10)
      CanvasUtils.roundRect(ctx, 41 * scale, 1 * scale, 16 * scale, 14 * scale, 7 * scale, true, true)
    else if (count < 100)
      CanvasUtils.roundRect(ctx, 37 * scale, 1 * scale, 20 * scale, 14 * scale, 7 * scale, true, true)
      textX = 46
    else
      CanvasUtils.roundRect(ctx, 33 * scale, 1 * scale, 25 * scale, 14 * scale, 7 * scale, true, true)
      text = "99+"
      textX = 46

    # count text
    ctx.fillStyle = "rgba(255,255,255,0.9)"
    ctx.font = "#{11 * scale}px sans-serif"
    ctx.textAlign = "center"
    ctx.fillText(text, textX * scale, 12 * scale, 30 * scale)

    return DragCanvas

  measureTextInCanvas: (text, font) ->
    canvas = document.createElement('canvas')
    context = canvas.getContext('2d')
    context.font = font
    return Math.ceil(context.measureText(text).width)

  canvasWithSystemTrayIconAndText: (img, text) ->
    canvas = SystemTrayCanvas
    w = img.width
    h = img.height
    font = '14px Nylas-Pro, sans-serif'

    textWidth = if text.length > 0 then CanvasUtils.measureTextInCanvas(text, font) + 2 else 0
    canvas.width = w + textWidth
    canvas.height = h

    context = canvas.getContext('2d')
    context.font = font
    context.fillStyle = 'black'
    context.textAlign = 'start'
    context.textBaseline = 'middle'

    context.drawImage(img, 0, 0)
    # Place after img, vertically aligned
    context.fillText(text, w, h / 2)
    return canvas

module.exports = CanvasUtils
