_ = require('underscore')
fs = require('fs')
path = require 'path'
QuotedHTMLTransformer = require('../../src/services/quoted-html-transformer').default

describe "QuotedHTMLTransformer", ->

  readFile = (fname) ->
    emailPath = path.resolve(__dirname, '..', 'fixtures', 'emails', fname)
    return fs.readFileSync(emailPath, 'utf8')

  hideQuotedHTML = (fname) ->
    return QuotedHTMLTransformer.hideQuotedHTML(readFile(fname))

  removeQuotedHTML = (fname, opts={}) ->
    return QuotedHTMLTransformer.removeQuotedHTML(readFile(fname), opts)

  numQuotes = (html) ->
    re = new RegExp(QuotedHTMLTransformer.annotationClass, 'g')
    html.match(re)?.length ? 0

  [1..23].forEach (n) ->
    it "properly parses email_#{n}", ->
      opts = keepIfWholeBodyIsQuote: true
      expect(removeQuotedHTML("email_#{n}.html", opts).trim()).toEqual(readFile("email_#{n}_stripped.html").trim())

  describe 'manual quote detection tests', ->

    clean = (str) ->
      str.replace(/[\n\r]/g, "").replace(/\s{2,}/g, " ")

    # The key is the inHTML. The value is the outHTML
    tests = []

    # Test 1
    tests.push
      before: """
        <div>
          Some text

          <p>More text</p>

          <blockquote id="inline-parent-quote">
            Parent
            <blockquote id="inline-sub-quote">
              Sub
              <blockquote id="inline-sub-sub-quote">Sub Sub</blockquote>
              Sub
            </blockquote>
          </blockquote>

          <div>Text at end</div>

          <blockquote id="last-quote">
            <blockquote>
              The last quote!
            </blockquote>
          </blockquote>


        </div>
        """
      after: """
        <div>
          Some text

          <p>More text</p>

          <blockquote id="inline-parent-quote">
            Parent
            <blockquote id="inline-sub-quote">
              Sub
              <blockquote id="inline-sub-sub-quote">Sub Sub</blockquote>
              Sub
            </blockquote>
          </blockquote>

          <div>Text at end</div>
         </div>
        """

    # Test 2: Basic quote removal
    tests.push
      before: """
        <br>
        Yo
        <blockquote>Nothing but quotes</blockquote>
        <br>
        <br>
        """
      after: """
        <br>
        Yo
        <br>
        <br>
        """

    # Test 3: It found the blockquote in another div
    tests.push
      before: """
        <div>Hello World</div>
        <br>
        <div>
          <blockquote>Nothing but quotes</blockquote>
        </div>
        <br>
        <br>
        """
      after: """
        <div>Hello World</div>
        <br>
        <div>
         </div>
        <br>
        <br>
        """

      # Test 4: It works inside of a wrapped div
    tests.push
      before: """
        <div>
          <br>
          <blockquote>Nothing but quotes</blockquote>
          <br>
          <br>
        </div>
        """
      after: """
        <div>
          <br>
          <br>
          <br>
        </div>
        """

    # Test 5: Inline quotes and text
    tests.push
      before: """
        Hello
        <blockquote>Inline quote</blockquote>
        World
        """
      after: """
        Hello
        <blockquote>Inline quote</blockquote>
        World
        """

    # Test 6: No quoted elements at all
    tests.push
      before: """
        Hello World
        """
      after: """
        Hello World
        """

    # Test 7: Common ancestor is a quoted node
    tests.push
      before: """
        <div>Content</div>
        <blockquote>
          Some content
          <blockquote>More content</blockquote>
          Other content
        </blockquote>
        """
      after: """
        <div>Content</div>
        """

    # Test 8: All of our quote blocks we want to remove are at the end…
    # sortof… but nested in a bunch of stuff
    #
    # Note that "content" is burried deep in the middle of a div
    tests.push
      before: """
        <div>Content</div>
        <blockquote>
          Some content
          <blockquote>More content</blockquote>
          Other content
        </blockquote>
        <div>
          <blockquote>Some text quote</blockquote>
          Some text
          <div>
            More text
            <blockquote>A quote</blockquote>
            <br>
          </div>
          <br>
          <blockquote>Another quote</blockquote>
          <br>
        </div>
        <br>
        <blockquote>More quotes!</blockquote>
        """
      after: """
        <div>Content</div>
        <blockquote>
          Some content
          <blockquote>More content</blockquote>
          Other content
        </blockquote>
        <div>
          <blockquote>Some text quote</blockquote>
          Some text
          <div>
            More text
            <br>
          </div>
          <br>
          <br>
        </div>
        <br>

        """

    # Test 9: Last several tags are blockquotes. Note the 3 blockquote
    # at the end, the interstital div, and the blockquote inside of the
    # first div
    tests.push
      before: """
        <div>
          <blockquote>I'm inline</blockquote>
          Content
          <blockquote>Remove me</blockquote>
        </div>
        <blockquote>Foo</blockquote>
        <div></div>
        <blockquote>Bar</blockquote>
        <blockquote>Baz</blockquote>
        """
      after: """
        <div>
          <blockquote>I'm inline</blockquote>
          Content
         </div>
        <div></div>
        """

    # Test 10: If it's only a quote and no other text, then just show the
    # quote
    tests.push
      before: """
        <br>
        <blockquote>Nothing but quotes</blockquote>
        <br>
        <br>
        """
      after: """
        <br>
        <blockquote>Nothing but quotes</blockquote>
        <br>
        <br>
        """


    # Test 11: The <body> tag itself is just a quoted text block.
    # I believe this is https://sentry.nylas.com/sentry/edgehill/group/8323/
    tests.push
      before: """
        <body id="OLK_SRC_BODY_SECTION">
          This entire thing is quoted text!
        </body>
        """
      after: "<head></head><body></body>"
      options: { keepIfWholeBodyIsQuote: false }

    # Test 12: Make sure that a single quote inside of a bunch of other
    # content is detected. We used to have a bug where we were only
    # looking at the common ancestor of blockquotes (and if there's 1 then
    # the ancestor is itself). We now look at the root document for
    # trailing text.
    tests.push
      before: """
        <br>
        Yo
        <table><tbody>
          <tr><td>A</td><td>B</td></tr>
          <tr><td>C</td><td><blockquote>SAVE ME</blockquote></td></tr>
          <tr><td>E</td><td>F</td></tr>
        </tbody></table>
        Yo
        <br>
        """
      after: """
        <br>
        Yo
        <table><tbody>
          <tr><td>A</td><td>B</td></tr>
          <tr><td>C</td><td><blockquote>SAVE ME</blockquote></td></tr>
          <tr><td>E</td><td>F</td></tr>
        </tbody></table>
        Yo
        <br>
        """

    # Test 13: If there's an "On date…" string immediatley before a blockquote,
    # then remove it.
    tests.push
      before: """
        Hey
        <div>
          On FOOBAR
          <br>
          On Thu, Mar 3, 2016
          at 3:19 AM,
          First Middle Last-Last
          <span dir="ltr">
            &lt;
            <a href="mailto:test@nylas.com" target="_blank">
              test@nylas.com
            </a>
            &gt;
          </span>
          wrote:
          <br>
          <blockquote>
            QUOTED TEXT
          </blockquote>
        </div>
        <br>
      """
      after: """
        Hey
        <div>
          On FOOBAR
          <br><br>
          </div><br>
      """

    # Test 14: Don't pick up false positives on the string precursors to block
    # quotes.
    tests.push
      before: """
        Hey
        <div>
        On FOOBAR
        <br>
        On Thu, Mar 3, 2016 I went to my writing club and wrote:
        <strong>A little song</strong>
        <blockquote>
          QUOTED TEXT
        </blockquote>
        </div>
      """
      after: """
        Hey
        <div>
        On FOOBAR
        <br>
        On Thu, Mar 3, 2016 I went to my writing club and wrote:
        <strong>A little song</strong>
        </div>
      """

    # Test 15: Make sure inline quote in plaintext converted to HTML with <pre>
    # is not completely stripped.
    tests.push
      before: """
        <pre class="nylas-plaintext">On Wed, Dec 14, 2016 at 02:05:44PM +0100, Bálint Réczey wrote:
        &gt; I have uploaded a dpkg NMU with bindnow enabled to DELAYED/10
        &gt; according to current NMU rules. If the Release Team increases the
        &gt; severity of #835146 it can reach unstable earlier.
        Thanks!

        --
        WBR, wRAR
        </pre>
      """
      after: """
        <pre class="nylas-plaintext">On Wed, Dec 14, 2016 at 02:05:44PM +0100, Bálint Réczey wrote:
        &gt; I have uploaded a dpkg NMU with bindnow enabled to DELAYED/10
        &gt; according to current NMU rules. If the Release Team increases the
        &gt; severity of #835146 it can reach unstable earlier.
        Thanks!

        --
        WBR, wRAR
        </pre>
      """

    it 'works with these manual test cases', ->
      for {before, after, options} in tests
        if not options
          options = {keepIfWholeBodyIsQuote: true}
        test = clean(QuotedHTMLTransformer.removeQuotedHTML(before, options))
        expect(test).toEqual clean(after)

    it 'removes all trailing <br> tags except one', ->
      input0 = "hello world<br><br><blockquote>foolololol</blockquote>"
      expect0 = "hello world<br>"
      expect(QuotedHTMLTransformer.removeQuotedHTML(input0)).toEqual expect0

    it 'preserves <br> tags in the middle and only chops off tail', ->
      input0 = "hello<br><br>world<br><br><blockquote>foolololol</blockquote>"
      expect0 = "hello<br><br>world<br>"
      expect(QuotedHTMLTransformer.removeQuotedHTML(input0)).toEqual expect0

    it 'works as expected when body tag inside the html', ->
      input0 = """
      <br><br><blockquote class="gmail_quote"
        style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
        On Dec 16 2015, at 7:08 pm, Juan Tejada &lt;juan@nylas.com&gt; wrote:
        <br>


      <meta content="text/html; charset=us-ascii" />

      <body>
      <h1 id="h2">h2</h1>
      <p>he he hehehehehehe</p>
      <p>dufjcasc</p>


      </blockquote>
      """
      expect0 = "<head></head><body><br></body>"
      expect(QuotedHTMLTransformer.removeQuotedHTML(input0, {keepIfWholeBodyIsQuote: false})).toEqual expect0


  # We have a little utility method that you can manually uncomment to
  # generate what the current iteration of the QuotedHTMLTransformer things the
  # `removeQuotedHTML` should look like. These can be manually inspected in
  # a browser before getting their filename changed to
  # `email_#{n}_stripped.html". The actually tests will run the current
  # iteration of the `removeQuotedHTML` against these files to catch if
  # anything has changed in the parser.
  #
  # It's inside of the specs here instaed of its own script because the
  # `QuotedHTMLTransformer` needs Electron booted up in order to work because
  # of the DOMParser.
  xit "Run this simple function to generate output files", ->
    [18, 20].forEach (n) ->
      newHTML = QuotedHTMLTransformer.removeQuotedHTML(readFile("email_#{n}.html"))
      outPath = path.resolve(__dirname, '..', 'fixtures', 'emails', "email_#{n}_raw_stripped.html")
      fs.writeFileSync(outPath, newHTML)
