# {APIError} = require '../../src/flux/errors'
# Task = require '../../src/flux/tasks/task'
# _ = require 'underscore-plus'
#
# describe "Task", ->
#   beforeEach ->
#     @task = new Task()
#
#   describe "shouldRetry", ->
#
#     it "should default to false if the error does not have a status code", ->
#       expect(@task.shouldRetry(new Error())).toBe(false)
#
#     # Should Not Retry
#
#     it "should return false when the error is a 401 Unauthorized from the API", ->
#       expect(@task.shouldRetry(new APIError({statusCode: 401}))).toBe(false)
#
#     it "should return false when the error is a 403 Forbidden from the API", ->
#       expect(@task.shouldRetry(new APIError({statusCode: 403}))).toBe(false)
#
#     it "should return false when the error is a 404 Not Found from the API", ->
#       expect(@task.shouldRetry(new APIError({statusCode: 404}))).toBe(false)
#
#     it "should return false when the error is a 405 Method Not Allowed from the API", ->
#       expect(@task.shouldRetry(new APIError({statusCode: 405}))).toBe(false)
#
#     it "should return false when the error is a 406 Not Acceptable from the API", ->
#       expect(@task.shouldRetry(new APIError({statusCode: 406}))).toBe(false)
#
#     it "should return false when the error is a 409 Conflict from the API", ->
#       expect(@task.shouldRetry(new APIError({statusCode: 409}))).toBe(false)
#
#     # Should Retry
#
#     it "should return true when the error is 0 Request Not Made from the API", ->
#       expect(@task.shouldRetry(new APIError({statusCode: 0}))).toBe(true)
#
#     it "should return true when the error is 407 Proxy Authentication Required from the API", ->
#       expect(@task.shouldRetry(new APIError({statusCode: 407}))).toBe(true)
#
#     it "should return true when the error is 408 Request Timeout from the API", ->
#       expect(@task.shouldRetry(new APIError({statusCode: 408}))).toBe(true)
#
#     it "should return true when the error is 305 Use Proxy from the API", ->
#       expect(@task.shouldRetry(new APIError({statusCode: 305}))).toBe(true)
#
#     it "should return true when the error is 502 Bad Gateway from the API", ->
#       expect(@task.shouldRetry(new APIError({statusCode: 502}))).toBe(true)
#
#     it "should return true when the error is 503 Service Unavailable from the API", ->
#       expect(@task.shouldRetry(new APIError({statusCode: 503}))).toBe(true)
#
#     it "should return true when the error is 504 Gateway Timeout from the API", ->
#       expect(@task.shouldRetry(new APIError({statusCode: 504}))).toBe(true)
#
