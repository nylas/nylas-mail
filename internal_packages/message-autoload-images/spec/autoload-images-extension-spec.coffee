fs = require 'fs'
AutoloadImagesExtension = require '../lib/autoload-images-extension'
AutoloadImagesStore = require '../lib/autoload-images-store'

describe "AutoloadImagesExtension", ->
  describe "formatMessageBody", ->
    scenarios = []
    fixtures = path.resolve(path.join(__dirname, 'fixtures'))
    for filename in fs.readdirSync(fixtures)
      if filename[-8..-1] is '-in.html'
        scenarios.push
          name: filename[0..-9]
          in: fs.readFileSync(path.join(fixtures, filename)).toString()
          out: fs.readFileSync(path.join(fixtures, "#{filename[0..-9]}-out.html")).toString()

    scenarios.forEach (scenario) =>
      it "should process #{scenario.name}", ->
        spyOn(AutoloadImagesStore, 'shouldBlockImagesIn').andReturn(true)
        message =
          body: scenario.in
        AutoloadImagesExtension.formatMessageBody({message})
        expect(message.body == scenario.out).toBe(true)

module.exports = AutoloadImagesExtension
