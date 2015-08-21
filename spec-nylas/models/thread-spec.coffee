{generateTempId} = require '../../src/flux/models/utils'
Message = require '../../src/flux/models/message'
Thread = require '../../src/flux/models/thread'
_ = require 'underscore'

mockThread =
  accountId: "abc"
  participants: ["zip@example.com"]
  subject: "blah"
  id: "asdf"

describe 'Thread', ->
