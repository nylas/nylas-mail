# This is modied from https://github.com/mko/emailreplyparser, which is a
# JS port of GitHub's Ruby https://github.com/github/email_reply_parser

fs = require('fs')
path = require 'path'
_ = require('underscore')
QuotedPlainTextParser = require('../src/services/quoted-plain-text-parser')

getParsedEmail = (name, format="plain") ->
  data = getRawEmail(name, format)
  reply = QuotedPlainTextParser.parse data, format
  reply._setHiddenState()
  return reply

getRawEmail = (name, format="plain") ->
  emailPath = path.resolve(__dirname, 'fixtures', 'emails', "#{name}.txt")
  return fs.readFileSync(emailPath, "utf8")

deepEqual = (expected=[], test=[]) ->
  for toExpect, i in expected
    expect(test[i]).toBe toExpect

describe "QuotedPlainTextParser", ->
  it "reads_simple_body", ->
    reply = getParsedEmail('email_1_1')
    expect(reply.fragments.length).toBe 3
    deepEqual [
      false
      false
      false
    ], _.map(reply.fragments, (f) ->
      f.quoted
    )
    deepEqual [
      false
      true
      true
    ], _.map(reply.fragments, (f) ->
      f.signature
    )
    deepEqual [
      false
      true
      true
    ], _.map(reply.fragments, (f) ->
      f.hidden
    )
    expect(reply.fragments[0].to_s()).toEqual 'Hi folks\n\nWhat is the best way to clear a Riak bucket of all key, values after\nrunning a test?\nI am currently using the Java HTTP API.'
    expect(reply.fragments[1].to_s()).toEqual '-Abhishek Kona'

  it "reads_top_post", ->
    reply = getParsedEmail('email_1_3')
    expect(reply.fragments.length).toEqual 5

    deepEqual [
      false
      false
      true
      false
      false
    ], _.map(reply.fragments, (f) ->
      f.quoted
    )
    deepEqual [
      false
      true
      true
      true
      true
    ], _.map(reply.fragments, (f) ->
      f.hidden
    )
    deepEqual [
      false
      true
      false
      false
      true
    ], _.map(reply.fragments, (f) ->
      f.signature
    )
    expect(new RegExp('^Oh thanks.\n\nHaving').test(reply.fragments[0].to_s())).toBe true
    expect(new RegExp('^-A').test(reply.fragments[1].to_s())).toBe true
    expect(/^On [^\:]+\:/m.test(reply.fragments[2].to_s())).toBe true
    expect(new RegExp('^_').test(reply.fragments[4].to_s())).toBe true

  it "reads_bottom_post", ->
    reply = getParsedEmail('email_1_2')
    expect(reply.fragments.length).toEqual 6
    deepEqual [
      false
      true
      false
      true
      false
      false
    ], _.map(reply.fragments, (f) ->
      f.quoted
    )
    deepEqual [
      false
      false
      false
      false
      false
      true
    ], _.map(reply.fragments, (f) ->
      f.signature
    )
    deepEqual [
      false
      false
      false
      true
      true
      true
    ], _.map(reply.fragments, (f) ->
      f.hidden
    )
    expect(reply.fragments[0].to_s()).toEqual 'Hi,'
    expect(new RegExp('^On [^:]+:').test(reply.fragments[1].to_s())).toBe true
    expect(/^You can list/m.test(reply.fragments[2].to_s())).toBe true
    expect(/^> /m.test(reply.fragments[3].to_s())).toBe true
    expect(new RegExp('^_').test(reply.fragments[5].to_s())).toBe true

  it "reads_inline_replies", ->
    reply = getParsedEmail('email_1_8')
    expect(reply.fragments.length).toEqual 7
    deepEqual [
      true
      false
      true
      false
      true
      false
      false
    ], _.map(reply.fragments, (f) ->
      f.quoted
    )
    deepEqual [
      false
      false
      false
      false
      false
      false
      true
    ], _.map(reply.fragments, (f) ->
      f.signature
    )
    deepEqual [
      false
      false
      false
      false
      true
      true
      true
    ], _.map(reply.fragments, (f) ->
      f.hidden
    )
    expect(new RegExp('^On [^:]+:').test(reply.fragments[0].to_s())).toBe true
    expect(/^I will reply/m.test(reply.fragments[1].to_s())).toBe true
    expect(/^> /m.test(reply.fragments[2].to_s())).toBe true
    expect(/^and under this./m.test(reply.fragments[3].to_s())).toBe true
    expect(/^> /m.test(reply.fragments[4].to_s())).toBe true
    expect(reply.fragments[5].to_s().trim()).toEqual ''
    expect(new RegExp('^-').test(reply.fragments[6].to_s())).toBe true

  it "recognizes_date_string_above_quote", ->
    reply = getParsedEmail('email_1_4')
    expect(/^Awesome/.test(reply.fragments[0].to_s())).toBe true
    expect(/^On/m.test(reply.fragments[1].to_s())).toBe true
    expect(/Loader/m.test(reply.fragments[1].to_s())).toBe true

  it "a_complex_body_with_only_one_fragment", ->
    reply = getParsedEmail('email_1_5')
    expect(reply.fragments.length).toEqual 1

  it "reads_email_with_correct_signature", ->
    reply = getParsedEmail('correct_sig')
    expect(reply.fragments.length).toEqual 2
    deepEqual [
      false
      false
    ], _.map(reply.fragments, (f) ->
      f.quoted
    )
    deepEqual [
      false
      true
    ], _.map(reply.fragments, (f) ->
      f.signature
    )
    deepEqual [
      false
      true
    ], _.map(reply.fragments, (f) ->
      f.hidden
    )
    expect(new RegExp('^-- \nrick').test(reply.fragments[1].to_s())).toBe true

  it "deals_with_multiline_reply_headers", ->
    reply = getParsedEmail('email_1_6')
    expect(new RegExp('^I get').test(reply.fragments[0].to_s())).toBe true
    expect(/^On/m.test(reply.fragments[1].to_s())).toBe true
    expect(new RegExp('Was this').test(reply.fragments[1].to_s())).toBe true

  it "does_not_modify_input_string", ->
    original = 'The Quick Brown Fox Jumps Over The Lazy Dog'
    QuotedPlainTextParser.parse original
    expect(original).toEqual 'The Quick Brown Fox Jumps Over The Lazy Dog'

  it "returns_only_the_visible_fragments_as_a_string", ->
    reply = getParsedEmail('email_2_1')

    String::rtrim = ->
      @replace /\s*$/g, ''

    fragments = _.select(reply.fragments, (f) ->
      !f.hidden
    )
    fragments = _.map(fragments, (f) ->
      f.to_s()
    )
    expect(reply.visibleText(format: "plain")).toEqual fragments.join('\n').rtrim()

  it "parse_out_just_top_for_outlook_reply", ->
    body = getRawEmail('email_2_1')
    expect(QuotedPlainTextParser.visibleText(body, format: "plain")).toEqual 'Outlook with a reply'

  it "parse_out_sent_from_iPhone", ->
    body = getRawEmail('email_iPhone')
    expect(QuotedPlainTextParser.visibleText(body, format: "plain")).toEqual 'Here is another email'

  it "parse_out_sent_from_BlackBerry", ->
    body = getRawEmail('email_BlackBerry')
    expect(QuotedPlainTextParser.visibleText(body, format: "plain")).toEqual 'Here is another email'

  it "parse_out_send_from_multiword_mobile_device", ->
    body = getRawEmail('email_multi_word_sent_from_my_mobile_device')
    expect(QuotedPlainTextParser.visibleText(body, format: "plain")).toEqual 'Here is another email'

  it "do_not_parse_out_send_from_in_regular_sentence", ->
    body = getRawEmail('email_sent_from_my_not_signature')
    expect(QuotedPlainTextParser.visibleText(body, format: "plain")).toEqual 'Here is another email\n\nSent from my desk, is much easier then my mobile phone.'

  it "retains_bullets", ->
    body = getRawEmail('email_bullets')
    expect(QuotedPlainTextParser.visibleText(body, format: "plain")).toEqual 'test 2 this should list second\n\nand have spaces\n\nand retain this formatting\n\n\n   - how about bullets\n   - and another'

  it "visibleText", ->
    body = getRawEmail('email_1_2')
    expect(QuotedPlainTextParser.visibleText(body, format: "plain")).toEqual QuotedPlainTextParser.parse(body).visibleText(format: "plain")

  it "correctly_reads_top_post_when_line_starts_with_On", ->
    reply = getParsedEmail('email_1_7')
    expect(reply.fragments.length).toEqual 5
    deepEqual [
      false
      false
      true
      false
      false
    ], _.map(reply.fragments, (f) ->
      f.quoted
    )
    deepEqual [
      false
      true
      true
      true
      true
    ], _.map(reply.fragments, (f) ->
      f.hidden
    )
    deepEqual [
      false
      true
      false
      false
      true
    ], _.map(reply.fragments, (f) ->
      f.signature
    )
    expect(new RegExp('^Oh thanks.\n\nOn the').test(reply.fragments[0].to_s())).toBe true
    expect(new RegExp('^-A').test(reply.fragments[1].to_s())).toBe true
    expect(/^On [^\:]+\:/m.test(reply.fragments[2].to_s())).toBe true
    expect(new RegExp('^_').test(reply.fragments[4].to_s())).toBe true
