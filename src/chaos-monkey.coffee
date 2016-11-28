NylasAPI = require './flux/nylas-api'
nock = require 'nock'

# We be wrecking havok in your code
class ChaosMonkey
  @unleashOnAPI: ({errorCode, numMonkeys, makeTimeout}={}) ->
    errorCode ?= 500
    numMonkeys ?= "all the monkeys"
    makeTimeout ?= false
    nGet = nock(NylasAPI.APIRoot)
    nPut = nock(NylasAPI.APIRoot)
    nPost = nock(NylasAPI.APIRoot)

    numTimes = 1
    if numMonkeys.toLowerCase() is "all the monkeys"
      nGet = nGet.persist()
      nPut = nPut.persist()
      nPost = nPost.persist()
    else if _.isNumber(numMonkeys)
      numTimes = numMonkeys

    nGet = nGet.filteringPath (path) -> '/*'
      .get('/*')

    nPut = nPut.filteringRequestBody (body) -> '*'
      .filteringPath (path) -> '/*'
      .put('/*', '*')

    nPost = nPost.filteringRequestBody (body) -> '*'
      .filteringPath (path) -> '/*'
      .post('/*', '*')

    [nGet, nPut, nPost] = [nGet, nPut, nPost].map (n) ->
      n = n.times(numTimes)
      if makeTimeout
        return n.socketDelay(31000)
      else
        return n

    if makeTimeout
      [nGet, nPut, nPost].forEach (n) -> n.reply(200, 'Timed out')
    else
      nGet.replyWithError({message:'Monkey GET error!', code: errorCode})
      nPut.replyWithError({message:'Monkey PUT error!', code: errorCode})
      nPost.replyWithError({message:'Monkey POST error!', code: errorCode})

  @goHome: ->
    nock.restore()
    nock.cleanAll()

window.ChaosMonkey = ChaosMonkey
module.exports = ChaosMonkey
