class QueryRange
  @infinite: ->
    return new QueryRange({limit: null, offset: null})

  @rangeWithUnion: (a, b) ->
    return QueryRange.infinite() if a.isInfinite() or b.isInfinite()
    if not a.intersects(b)
      throw new Error('You cannot union ranges which do not overlap.')

    new QueryRange
      start: Math.min(a.start, b.start)
      end: Math.max(a.end, b.end)

  @rangesBySubtracting: (a, b) ->
    return [] unless b

    if a.isInfinite() or b.isInfinite()
      throw new Error("You cannot subtract infinite ranges.")

    uncovered = []
    if b.start > a.start
      uncovered.push new QueryRange({start: a.start, end: Math.min(a.end, b.start)})
    if b.end < a.end
      uncovered.push new QueryRange({start: Math.max(a.start, b.end), end: a.end})
    uncovered


  Object.defineProperty @prototype, "start",
    enumerable: false
    get: -> @offset

  Object.defineProperty @prototype, "end",
    enumerable: false
    get: -> @offset + @limit

  constructor: ({@limit, @offset, start, end} = {}) ->
    @offset ?= start if start?
    @limit ?= end - @offset if end?
    throw new Error("You must specify a limit") if @limit is undefined
    throw new Error("You must specify an offset") if @offset is undefined

  clone: ->
    return new QueryRange({@limit, @offset})

  isInfinite: ->
    return @limit is null and @offset is null

  isEqual: (b) ->
    return @start is b.start and @end is b.end

  intersects: (b) ->
    return true if @isInfinite() or b.isInfinite()
    return @start <= b.start <= @end or @start <= b.end <= @end

  toString: ->
    "QueryRange{#{@start} - #{@end}}"

module.exports = QueryRange
