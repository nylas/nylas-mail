_ = require('underscore')
RegExpUtils =

  # It's important that the regex be wrapped in parens, otherwise
  # javascript's RegExp::exec method won't find anything even when the
  # regex matches!
  #
  # It's also imporant we return a fresh copy of the RegExp every time. A
  # javascript regex is stateful and multiple functions using this method
  # will cause unexpected behavior!
  #
  # See http://tools.ietf.org/html/rfc5322#section-3.4 and
  # https://tools.ietf.org/html/rfc6531 and
  # https://en.wikipedia.org/wiki/Email_address#Local_part
  emailRegex: -> new RegExp(/([a-z.A-Z0-9!#$%&'*+\-/=?^_`{|}~;:]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,63})/g)

  # http://stackoverflow.com/questions/16631571/javascript-regular-expression-detect-all-the-phone-number-from-the-page-source
  # http://www.regexpal.com/?fam=94521
  # NOTE: This is not exhaustive, and balances what is technically a phone number
  # with what would be annoying to linkify. eg: 12223334444 does not match.
  phoneRegex: -> new RegExp(/([\+\(]+|\b)(?:(\d{1,3}[- ()]*)?)(\d{3})[- )]+(\d{3})[- ]+(\d{4})(?: *x(\d+))?\b/g)

  # http://stackoverflow.com/a/16463966
  # http://www.regexpal.com/?fam=93928
  # NOTE: This does not match full urls with `http` protocol components.
  domainRegex: -> new RegExp(/^(?!:\/\/)([a-zA-Z0-9-_]+\.)*[a-zA-Z0-9][a-zA-Z0-9-_]+\.[a-zA-Z]{2,11}?/i)

  # https://www.safaribooksonline.com/library/view/regular-expressions-cookbook/9780596802837/ch07s16.html
  ipAddressRegex: -> new RegExp(/^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/i)

  # Test cases: https://regex101.com/r/pD7iS5/3
  urlRegex: ({matchEntireString} = {}) ->
    commonTlds = ['com', 'org', 'edu', 'gov', 'uk', 'net', 'ca', 'de', 'jp', 'fr', 'au', 'us', 'ru', 'ch', 'it', 'nl', 'se', 'no', 'es', 'mil', 'ly']

    parts = [
      '('
        # one of:
        '('
          # This OR block matches any TLD if the URL includes a scheme, and only
          # the top ten TLDs if the scheme is omitted.
          # YES - https://nylas.ai
          # YES - https://10.2.3.1
          # YES - nylas.com
          # NO  - nylas.ai
          '('
            # scheme, ala https:// (mandatory)
            '([A-Za-z]{3,9}:(?:\\/\\/))'

            # username:password (optional)
            '(?:[\\-;:&=\\+\\$,\\w]+@)?'

            # one of:
            '('
              # domain with any tld
              '([a-zA-Z0-9-_]+\\.)*[a-zA-Z0-9][a-zA-Z0-9-_]+\\.[a-zA-Z]{2,11}'

              '|'

              # ip address
              '(?:[0-9]{1,3}\\.){3}[0-9]{1,3}'
            ')'

            '|'

            # scheme, ala https:// (optional)
            '([A-Za-z]{3,9}:(?:\\/\\/))?'

            # username:password (optional)
            '(?:[\\-;:&=\\+\\$,\\w]+@)?'

            # one of:
            '('
              # domain with common tld
              '([a-zA-Z0-9-_]+\\.)*[a-zA-Z0-9][a-zA-Z0-9-_]+\\.(?:' + commonTlds.join('|') + ')'

              '|'

              # ip address
              '(?:[0-9]{1,3}\\.){3}[0-9]{1,3}'
            ')'
          ')'

          # :port (optional)
          '(?::\d*)?'

          '|'

          # mailto:username@password.com
          'mailto:\\/*(?:\\w+\\.|[\\-;:&=\\+\\$.,\\w]+@)[A-Za-z0-9\\.\\-]+'
        ')'

        # optionally followed by:
        '('
          # URL components
          # (last character must not be puncation, hence two groups)
          '(?:[\\+~%\\/\\.\\w\\-_@]*[\\+~%\\/\\w\\-_]+)?'

          # optionally followed by: a query string and/or a #location
          # (last character must not be puncation, hence two groups)
          '(?:(\\?[\\-\\+=&;%@\\.\\w_]*[\\-\\+=&;%@\\w_\\/]+)?#?(?:[\'\\$\\&\\(\\)\\*\\+,;=\\.\\!\\/\\\\\\w%-]*[\\/\\\\\\w]+)?)?'
        ')?'
      ')'
    ]
    if matchEntireString
      parts.unshift('^')

    return new RegExp(parts.join(''), 'gi')

  # Test cases: https://regex101.com/r/jD5zC7/2
  # Returns the following capturing groups:
  # 1. start of the opening a tag to href="
  # 2. The contents of the href without quotes
  # 3. the rest of the opening a tag
  # 4. the contents of the a tag
  # 5. the closing tag
  linkTagRegex: -> new RegExp(/(<a.*?href\s*?=\s*?['"])(.*?)(['"].*?>)([\s\S]*?)(<\/a>)/gim)

  # Test cases: https://regex101.com/r/cK0zD8/4
  # Catches link tags containing which are:
  # - Non empty
  # - Not a mailto: link
  # Returns the following capturing groups:
  # 1. start of the opening a tag to href="
  # 2. The contents of the href without quotes
  # 3. the rest of the opening a tag
  # 4. the contents of the a tag
  # 5. the closing tag
  urlLinkTagRegex: -> new RegExp(/(<a.*?href\s*?=\s*?['"])((?!mailto).+?)(['"].*?>)([\s\S]*?)(<\/a>)/gim)

  # https://regex101.com/r/zG7aW4/3
  imageTagRegex: -> /<img\s+[^>]*src="([^"]*)"[^>]*>/g

  punctuation: ({exclude}={}) ->
    exclude ?= []
    punctuation = [ '.', ',', '\\/', '#', '!', '$', '%', '^', '&', '*',
      ';', ':', '{', '}', '=', '\\-', '_', '`', '~', '(', ')', '@', '+',
      '?', '>', '<', '\\[', '\\]', '+' ]
    punctuation = _.difference(punctuation, exclude).join('')
    return new RegExp("[#{punctuation}]", 'g')

  # This tests for valid schemes as per RFC 3986
  # We need both http: https: and mailto: and a variety of other schemes.
  # This does not check for invalid usage of the http: scheme. For
  # example, http:bad.com would pass. We do not check for
  # protocol-relative uri's.
  #
  # Regex explanation here: https://regex101.com/r/nR2yL6/2
  # See RFC here: https://tools.ietf.org/html/rfc3986#section-3.1
  # SO discussion: http://stackoverflow.com/questions/10687099/how-to-test-if-a-url-string-is-absolute-or-relative/31991870#31991870
  hasValidSchemeRegex: -> new RegExp('^[a-z][a-z0-9+.-]*:', 'i')

  emojiRegex: -> /\u00A9|\u00AE|\u203C|\u2049|\u2122|\u2139|\u2194|\u2195|\u2196|\u2197|\u2198|\u2199|\u21A9|\u21AA|\u231A|\u231B|\u2328|\u23E9|\u23EA|\u23EB|\u23EC|\u23ED|\u23EE|\u23EF|\u23F0|\u23F1|\u23F2|\u23F3|\u23F8|\u23F9|\u23FA|\u24C2|\u25AA|\u25AB|\u25B6|\u25C0|\u25FB|\u25FC|\u25FD|\u25FE|\u2600|\u2601|\u2602|\u2603|\u2604|\u260E|\u2611|\u2614|\u2615|\u2618|\u261D|\u2620|\u2622|\u2623|\u2626|\u262A|\u262E|\u262F|\u2638|\u2639|\u263A|\u2648|\u2649|\u264A|\u264B|\u264C|\u264D|\u264E|\u264F|\u2650|\u2651|\u2652|\u2653|\u2660|\u2663|\u2665|\u2666|\u2668|\u267B|\u267F|\u2692|\u2693|\u2694|\u2696|\u2697|\u2699|\u269B|\u269C|\u26A0|\u26A1|\u26AA|\u26AB|\u26B0|\u26B1|\u26BD|\u26BE|\u26C4|\u26C5|\u26C8|\u26CE|\u26CF|\u26D1|\u26D3|\u26D4|\u26E9|\u26EA|\u26F0|\u26F1|\u26F2|\u26F3|\u26F4|\u26F5|\u26F7|\u26F8|\u26F9|\u26FA|\u26FD|\u2702|\u2705|\u2708|\u2709|\u270A|\u270B|\u270C|\u270D|\u270F|\u2712|\u2714|\u2716|\u271D|\u2721|\u2728|\u2733|\u2734|\u2744|\u2747|\u274C|\u274E|\u2753|\u2754|\u2755|\u2757|\u2763|\u2764|\u2795|\u2796|\u2797|\u27A1|\u27B0|\u27BF|\u2934|\u2935|\u2B05|\u2B06|\u2B07|\u2B1B|\u2B1C|\u2B50|\u2B55|\u3030|\u303D|\u3297|\u3299|\u1F004|\u1F0CF|\u1F170|\u1F171|\u1F17E|\u1F17F|\u1F18E|\u1F191|\u1F192|\u1F193|\u1F194|\u1F195|\u1F196|\u1F197|\u1F198|\u1F199|\u1F19A|\u1F201|\u1F202|\u1F21A|\u1F22F|\u1F232|\u1F233|\u1F234|\u1F235|\u1F236|\u1F237|\u1F238|\u1F239|\u1F23A|\u1F250|\u1F251|\u1F300|\u1F301|\u1F302|\u1F303|\u1F304|\u1F305|\u1F306|\u1F307|\u1F308|\u1F309|\u1F30A|\u1F30B|\u1F30C|\u1F30D|\u1F30E|\u1F30F|\u1F310|\u1F311|\u1F312|\u1F313|\u1F314|\u1F315|\u1F316|\u1F317|\u1F318|\u1F319|\u1F31A|\u1F31B|\u1F31C|\u1F31D|\u1F31E|\u1F31F|\u1F320|\u1F321|\u1F324|\u1F325|\u1F326|\u1F327|\u1F328|\u1F329|\u1F32A|\u1F32B|\u1F32C|\u1F32D|\u1F32E|\u1F32F|\u1F330|\u1F331|\u1F332|\u1F333|\u1F334|\u1F335|\u1F336|\u1F337|\u1F338|\u1F339|\u1F33A|\u1F33B|\u1F33C|\u1F33D|\u1F33E|\u1F33F|\u1F340|\u1F341|\u1F342|\u1F343|\u1F344|\u1F345|\u1F346|\u1F347|\u1F348|\u1F349|\u1F34A|\u1F34B|\u1F34C|\u1F34D|\u1F34E|\u1F34F|\u1F350|\u1F351|\u1F352|\u1F353|\u1F354|\u1F355|\u1F356|\u1F357|\u1F358|\u1F359|\u1F35A|\u1F35B|\u1F35C|\u1F35D|\u1F35E|\u1F35F|\u1F360|\u1F361|\u1F362|\u1F363|\u1F364|\u1F365|\u1F366|\u1F367|\u1F368|\u1F369|\u1F36A|\u1F36B|\u1F36C|\u1F36D|\u1F36E|\u1F36F|\u1F370|\u1F371|\u1F372|\u1F373|\u1F374|\u1F375|\u1F376|\u1F377|\u1F378|\u1F379|\u1F37A|\u1F37B|\u1F37C|\u1F37D|\u1F37E|\u1F37F|\u1F380|\u1F381|\u1F382|\u1F383|\u1F384|\u1F385|\u1F386|\u1F387|\u1F388|\u1F389|\u1F38A|\u1F38B|\u1F38C|\u1F38D|\u1F38E|\u1F38F|\u1F390|\u1F391|\u1F392|\u1F393|\u1F396|\u1F397|\u1F399|\u1F39A|\u1F39B|\u1F39E|\u1F39F|\u1F3A0|\u1F3A1|\u1F3A2|\u1F3A3|\u1F3A4|\u1F3A5|\u1F3A6|\u1F3A7|\u1F3A8|\u1F3A9|\u1F3AA|\u1F3AB|\u1F3AC|\u1F3AD|\u1F3AE|\u1F3AF|\u1F3B0|\u1F3B1|\u1F3B2|\u1F3B3|\u1F3B4|\u1F3B5|\u1F3B6|\u1F3B7|\u1F3B8|\u1F3B9|\u1F3BA|\u1F3BB|\u1F3BC|\u1F3BD|\u1F3BE|\u1F3BF|\u1F3C0|\u1F3C1|\u1F3C2|\u1F3C3|\u1F3C4|\u1F3C5|\u1F3C6|\u1F3C7|\u1F3C8|\u1F3C9|\u1F3CA|\u1F3CB|\u1F3CC|\u1F3CD|\u1F3CE|\u1F3CF|\u1F3D0|\u1F3D1|\u1F3D2|\u1F3D3|\u1F3D4|\u1F3D5|\u1F3D6|\u1F3D7|\u1F3D8|\u1F3D9|\u1F3DA|\u1F3DB|\u1F3DC|\u1F3DD|\u1F3DE|\u1F3DF|\u1F3E0|\u1F3E1|\u1F3E2|\u1F3E3|\u1F3E4|\u1F3E5|\u1F3E6|\u1F3E7|\u1F3E8|\u1F3E9|\u1F3EA|\u1F3EB|\u1F3EC|\u1F3ED|\u1F3EE|\u1F3EF|\u1F3F0|\u1F3F3|\u1F3F4|\u1F3F5|\u1F3F7|\u1F3F8|\u1F3F9|\u1F3FA|\u1F3FB|\u1F3FC|\u1F3FD|\u1F3FE|\u1F3FF|\u1F400|\u1F401|\u1F402|\u1F403|\u1F404|\u1F405|\u1F406|\u1F407|\u1F408|\u1F409|\u1F40A|\u1F40B|\u1F40C|\u1F40D|\u1F40E|\u1F40F|\u1F410|\u1F411|\u1F412|\u1F413|\u1F414|\u1F415|\u1F416|\u1F417|\u1F418|\u1F419|\u1F41A|\u1F41B|\u1F41C|\u1F41D|\u1F41E|\u1F41F|\u1F420|\u1F421|\u1F422|\u1F423|\u1F424|\u1F425|\u1F426|\u1F427|\u1F428|\u1F429|\u1F42A|\u1F42B|\u1F42C|\u1F42D|\u1F42E|\u1F42F|\u1F430|\u1F431|\u1F432|\u1F433|\u1F434|\u1F435|\u1F436|\u1F437|\u1F438|\u1F439|\u1F43A|\u1F43B|\u1F43C|\u1F43D|\u1F43E|\u1F43F|\u1F440|\u1F441|\u1F442|\u1F443|\u1F444|\u1F445|\u1F446|\u1F447|\u1F448|\u1F449|\u1F44A|\u1F44B|\u1F44C|\u1F44D|\u1F44E|\u1F44F|\u1F450|\u1F451|\u1F452|\u1F453|\u1F454|\u1F455|\u1F456|\u1F457|\u1F458|\u1F459|\u1F45A|\u1F45B|\u1F45C|\u1F45D|\u1F45E|\u1F45F|\u1F460|\u1F461|\u1F462|\u1F463|\u1F464|\u1F465|\u1F466|\u1F467|\u1F468|\u1F469|\u1F46A|\u1F46B|\u1F46C|\u1F46D|\u1F46E|\u1F46F|\u1F470|\u1F471|\u1F472|\u1F473|\u1F474|\u1F475|\u1F476|\u1F477|\u1F478|\u1F479|\u1F47A|\u1F47B|\u1F47C|\u1F47D|\u1F47E|\u1F47F|\u1F480|\u1F481|\u1F482|\u1F483|\u1F484|\u1F485|\u1F486|\u1F487|\u1F488|\u1F489|\u1F48A|\u1F48B|\u1F48C|\u1F48D|\u1F48E|\u1F48F|\u1F490|\u1F491|\u1F492|\u1F493|\u1F494|\u1F495|\u1F496|\u1F497|\u1F498|\u1F499|\u1F49A|\u1F49B|\u1F49C|\u1F49D|\u1F49E|\u1F49F|\u1F4A0|\u1F4A1|\u1F4A2|\u1F4A3|\u1F4A4|\u1F4A5|\u1F4A6|\u1F4A7|\u1F4A8|\u1F4A9|\u1F4AA|\u1F4AB|\u1F4AC|\u1F4AD|\u1F4AE|\u1F4AF|\u1F4B0|\u1F4B1|\u1F4B2|\u1F4B3|\u1F4B4|\u1F4B5|\u1F4B6|\u1F4B7|\u1F4B8|\u1F4B9|\u1F4BA|\u1F4BB|\u1F4BC|\u1F4BD|\u1F4BE|\u1F4BF|\u1F4C0|\u1F4C1|\u1F4C2|\u1F4C3|\u1F4C4|\u1F4C5|\u1F4C6|\u1F4C7|\u1F4C8|\u1F4C9|\u1F4CA|\u1F4CB|\u1F4CC|\u1F4CD|\u1F4CE|\u1F4CF|\u1F4D0|\u1F4D1|\u1F4D2|\u1F4D3|\u1F4D4|\u1F4D5|\u1F4D6|\u1F4D7|\u1F4D8|\u1F4D9|\u1F4DA|\u1F4DB|\u1F4DC|\u1F4DD|\u1F4DE|\u1F4DF|\u1F4E0|\u1F4E1|\u1F4E2|\u1F4E3|\u1F4E4|\u1F4E5|\u1F4E6|\u1F4E7|\u1F4E8|\u1F4E9|\u1F4EA|\u1F4EB|\u1F4EC|\u1F4ED|\u1F4EE|\u1F4EF|\u1F4F0|\u1F4F1|\u1F4F2|\u1F4F3|\u1F4F4|\u1F4F5|\u1F4F6|\u1F4F7|\u1F4F8|\u1F4F9|\u1F4FA|\u1F4FB|\u1F4FC|\u1F4FD|\u1F4FF|\u1F500|\u1F501|\u1F502|\u1F503|\u1F504|\u1F505|\u1F506|\u1F507|\u1F508|\u1F509|\u1F50A|\u1F50B|\u1F50C|\u1F50D|\u1F50E|\u1F50F|\u1F510|\u1F511|\u1F512|\u1F513|\u1F514|\u1F515|\u1F516|\u1F517|\u1F518|\u1F519|\u1F51A|\u1F51B|\u1F51C|\u1F51D|\u1F51E|\u1F51F|\u1F520|\u1F521|\u1F522|\u1F523|\u1F524|\u1F525|\u1F526|\u1F527|\u1F528|\u1F529|\u1F52A|\u1F52B|\u1F52C|\u1F52D|\u1F52E|\u1F52F|\u1F530|\u1F531|\u1F532|\u1F533|\u1F534|\u1F535|\u1F536|\u1F537|\u1F538|\u1F539|\u1F53A|\u1F53B|\u1F53C|\u1F53D|\u1F549|\u1F54A|\u1F54B|\u1F54C|\u1F54D|\u1F54E|\u1F550|\u1F551|\u1F552|\u1F553|\u1F554|\u1F555|\u1F556|\u1F557|\u1F558|\u1F559|\u1F55A|\u1F55B|\u1F55C|\u1F55D|\u1F55E|\u1F55F|\u1F560|\u1F561|\u1F562|\u1F563|\u1F564|\u1F565|\u1F566|\u1F567|\u1F56F|\u1F570|\u1F573|\u1F574|\u1F575|\u1F576|\u1F577|\u1F578|\u1F579|\u1F587|\u1F58A|\u1F58B|\u1F58C|\u1F58D|\u1F590|\u1F595|\u1F596|\u1F5A5|\u1F5A8|\u1F5B1|\u1F5B2|\u1F5BC|\u1F5C2|\u1F5C3|\u1F5C4|\u1F5D1|\u1F5D2|\u1F5D3|\u1F5DC|\u1F5DD|\u1F5DE|\u1F5E1|\u1F5E3|\u1F5E8|\u1F5EF|\u1F5F3|\u1F5FA|\u1F5FB|\u1F5FC|\u1F5FD|\u1F5FE|\u1F5FF|\u1F600|\u1F601|\u1F602|\u1F603|\u1F604|\u1F605|\u1F606|\u1F607|\u1F608|\u1F609|\u1F60A|\u1F60B|\u1F60C|\u1F60D|\u1F60E|\u1F60F|\u1F610|\u1F611|\u1F612|\u1F613|\u1F614|\u1F615|\u1F616|\u1F617|\u1F618|\u1F619|\u1F61A|\u1F61B|\u1F61C|\u1F61D|\u1F61E|\u1F61F|\u1F620|\u1F621|\u1F622|\u1F623|\u1F624|\u1F625|\u1F626|\u1F627|\u1F628|\u1F629|\u1F62A|\u1F62B|\u1F62C|\u1F62D|\u1F62E|\u1F62F|\u1F630|\u1F631|\u1F632|\u1F633|\u1F634|\u1F635|\u1F636|\u1F637|\u1F638|\u1F639|\u1F63A|\u1F63B|\u1F63C|\u1F63D|\u1F63E|\u1F63F|\u1F640|\u1F641|\u1F642|\u1F643|\u1F644|\u1F645|\u1F646|\u1F647|\u1F648|\u1F649|\u1F64A|\u1F64B|\u1F64C|\u1F64D|\u1F64E|\u1F64F|\u1F680|\u1F681|\u1F682|\u1F683|\u1F684|\u1F685|\u1F686|\u1F687|\u1F688|\u1F689|\u1F68A|\u1F68B|\u1F68C|\u1F68D|\u1F68E|\u1F68F|\u1F690|\u1F691|\u1F692|\u1F693|\u1F694|\u1F695|\u1F696|\u1F697|\u1F698|\u1F699|\u1F69A|\u1F69B|\u1F69C|\u1F69D|\u1F69E|\u1F69F|\u1F6A0|\u1F6A1|\u1F6A2|\u1F6A3|\u1F6A4|\u1F6A5|\u1F6A6|\u1F6A7|\u1F6A8|\u1F6A9|\u1F6AA|\u1F6AB|\u1F6AC|\u1F6AD|\u1F6AE|\u1F6AF|\u1F6B0|\u1F6B1|\u1F6B2|\u1F6B3|\u1F6B4|\u1F6B5|\u1F6B6|\u1F6B7|\u1F6B8|\u1F6B9|\u1F6BA|\u1F6BB|\u1F6BC|\u1F6BD|\u1F6BE|\u1F6BF|\u1F6C0|\u1F6C1|\u1F6C2|\u1F6C3|\u1F6C4|\u1F6C5|\u1F6CB|\u1F6CC|\u1F6CD|\u1F6CE|\u1F6CF|\u1F6D0|\u1F6E0|\u1F6E1|\u1F6E2|\u1F6E3|\u1F6E4|\u1F6E5|\u1F6E9|\u1F6EB|\u1F6EC|\u1F6F0|\u1F6F3|\u1F910|\u1F911|\u1F912|\u1F913|\u1F914|\u1F915|\u1F916|\u1F917|\u1F918|\u1F980|\u1F981|\u1F982|\u1F983|\u1F984|\u1F9C0|\u0023-20E3|\u002A-20E3|\u0030-20E3|\u0031-20E3|\u0032-20E3|\u0033-20E3|\u0034-20E3|\u0035-20E3|\u0036-20E3|\u0037-20E3|\u0038-20E3|\u0039-20E3|\u1F1E6-1F1E8|\u1F1E6-1F1E9|\u1F1E6-1F1EA|\u1F1E6-1F1EB|\u1F1E6-1F1EC|\u1F1E6-1F1EE|\u1F1E6-1F1F1|\u1F1E6-1F1F2|\u1F1E6-1F1F4|\u1F1E6-1F1F6|\u1F1E6-1F1F7|\u1F1E6-1F1F8|\u1F1E6-1F1F9|\u1F1E6-1F1FA|\u1F1E6-1F1FC|\u1F1E6-1F1FD|\u1F1E6-1F1FF|\u1F1E7-1F1E6|\u1F1E7-1F1E7|\u1F1E7-1F1E9|\u1F1E7-1F1EA|\u1F1E7-1F1EB|\u1F1E7-1F1EC|\u1F1E7-1F1ED|\u1F1E7-1F1EE|\u1F1E7-1F1EF|\u1F1E7-1F1F1|\u1F1E7-1F1F2|\u1F1E7-1F1F3|\u1F1E7-1F1F4|\u1F1E7-1F1F6|\u1F1E7-1F1F7|\u1F1E7-1F1F8|\u1F1E7-1F1F9|\u1F1E7-1F1FB|\u1F1E7-1F1FC|\u1F1E7-1F1FE|\u1F1E7-1F1FF|\u1F1E8-1F1E6|\u1F1E8-1F1E8|\u1F1E8-1F1E9|\u1F1E8-1F1EB|\u1F1E8-1F1EC|\u1F1E8-1F1ED|\u1F1E8-1F1EE|\u1F1E8-1F1F0|\u1F1E8-1F1F1|\u1F1E8-1F1F2|\u1F1E8-1F1F3|\u1F1E8-1F1F4|\u1F1E8-1F1F5|\u1F1E8-1F1F7|\u1F1E8-1F1FA|\u1F1E8-1F1FB|\u1F1E8-1F1FC|\u1F1E8-1F1FD|\u1F1E8-1F1FE|\u1F1E8-1F1FF|\u1F1E9-1F1EA|\u1F1E9-1F1EC|\u1F1E9-1F1EF|\u1F1E9-1F1F0|\u1F1E9-1F1F2|\u1F1E9-1F1F4|\u1F1E9-1F1FF|\u1F1EA-1F1E6|\u1F1EA-1F1E8|\u1F1EA-1F1EA|\u1F1EA-1F1EC|\u1F1EA-1F1ED|\u1F1EA-1F1F7|\u1F1EA-1F1F8|\u1F1EA-1F1F9|\u1F1EA-1F1FA|\u1F1EB-1F1EE|\u1F1EB-1F1EF|\u1F1EB-1F1F0|\u1F1EB-1F1F2|\u1F1EB-1F1F4|\u1F1EB-1F1F7|\u1F1EC-1F1E6|\u1F1EC-1F1E7|\u1F1EC-1F1E9|\u1F1EC-1F1EA|\u1F1EC-1F1EB|\u1F1EC-1F1EC|\u1F1EC-1F1ED|\u1F1EC-1F1EE|\u1F1EC-1F1F1|\u1F1EC-1F1F2|\u1F1EC-1F1F3|\u1F1EC-1F1F5|\u1F1EC-1F1F6|\u1F1EC-1F1F7|\u1F1EC-1F1F8|\u1F1EC-1F1F9|\u1F1EC-1F1FA|\u1F1EC-1F1FC|\u1F1EC-1F1FE|\u1F1ED-1F1F0|\u1F1ED-1F1F2|\u1F1ED-1F1F3|\u1F1ED-1F1F7|\u1F1ED-1F1F9|\u1F1ED-1F1FA|\u1F1EE-1F1E8|\u1F1EE-1F1E9|\u1F1EE-1F1EA|\u1F1EE-1F1F1|\u1F1EE-1F1F2|\u1F1EE-1F1F3|\u1F1EE-1F1F4|\u1F1EE-1F1F6|\u1F1EE-1F1F7|\u1F1EE-1F1F8|\u1F1EE-1F1F9|\u1F1EF-1F1EA|\u1F1EF-1F1F2|\u1F1EF-1F1F4|\u1F1EF-1F1F5|\u1F1F0-1F1EA|\u1F1F0-1F1EC|\u1F1F0-1F1ED|\u1F1F0-1F1EE|\u1F1F0-1F1F2|\u1F1F0-1F1F3|\u1F1F0-1F1F5|\u1F1F0-1F1F7|\u1F1F0-1F1FC|\u1F1F0-1F1FE|\u1F1F0-1F1FF|\u1F1F1-1F1E6|\u1F1F1-1F1E7|\u1F1F1-1F1E8|\u1F1F1-1F1EE|\u1F1F1-1F1F0|\u1F1F1-1F1F7|\u1F1F1-1F1F8|\u1F1F1-1F1F9|\u1F1F1-1F1FA|\u1F1F1-1F1FB|\u1F1F1-1F1FE|\u1F1F2-1F1E6|\u1F1F2-1F1E8|\u1F1F2-1F1E9|\u1F1F2-1F1EA|\u1F1F2-1F1EB|\u1F1F2-1F1EC|\u1F1F2-1F1ED|\u1F1F2-1F1F0|\u1F1F2-1F1F1|\u1F1F2-1F1F2|\u1F1F2-1F1F3|\u1F1F2-1F1F4|\u1F1F2-1F1F5|\u1F1F2-1F1F6|\u1F1F2-1F1F7|\u1F1F2-1F1F8|\u1F1F2-1F1F9|\u1F1F2-1F1FA|\u1F1F2-1F1FB|\u1F1F2-1F1FC|\u1F1F2-1F1FD|\u1F1F2-1F1FE|\u1F1F2-1F1FF|\u1F1F3-1F1E6|\u1F1F3-1F1E8|\u1F1F3-1F1EA|\u1F1F3-1F1EB|\u1F1F3-1F1EC|\u1F1F3-1F1EE|\u1F1F3-1F1F1|\u1F1F3-1F1F4|\u1F1F3-1F1F5|\u1F1F3-1F1F7|\u1F1F3-1F1FA|\u1F1F3-1F1FF|\u1F1F4-1F1F2|\u1F1F5-1F1E6|\u1F1F5-1F1EA|\u1F1F5-1F1EB|\u1F1F5-1F1EC|\u1F1F5-1F1ED|\u1F1F5-1F1F0|\u1F1F5-1F1F1|\u1F1F5-1F1F2|\u1F1F5-1F1F3|\u1F1F5-1F1F7|\u1F1F5-1F1F8|\u1F1F5-1F1F9|\u1F1F5-1F1FC|\u1F1F5-1F1FE|\u1F1F6-1F1E6|\u1F1F7-1F1EA|\u1F1F7-1F1F4|\u1F1F7-1F1F8|\u1F1F7-1F1FA|\u1F1F7-1F1FC|\u1F1F8-1F1E6|\u1F1F8-1F1E7|\u1F1F8-1F1E8|\u1F1F8-1F1E9|\u1F1F8-1F1EA|\u1F1F8-1F1EC|\u1F1F8-1F1ED|\u1F1F8-1F1EE|\u1F1F8-1F1EF|\u1F1F8-1F1F0|\u1F1F8-1F1F1|\u1F1F8-1F1F2|\u1F1F8-1F1F3|\u1F1F8-1F1F4|\u1F1F8-1F1F7|\u1F1F8-1F1F8|\u1F1F8-1F1F9|\u1F1F8-1F1FB|\u1F1F8-1F1FD|\u1F1F8-1F1FE|\u1F1F8-1F1FF|\u1F1F9-1F1E6|\u1F1F9-1F1E8|\u1F1F9-1F1E9|\u1F1F9-1F1EB|\u1F1F9-1F1EC|\u1F1F9-1F1ED|\u1F1F9-1F1EF|\u1F1F9-1F1F0|\u1F1F9-1F1F1|\u1F1F9-1F1F2|\u1F1F9-1F1F3|\u1F1F9-1F1F4|\u1F1F9-1F1F7|\u1F1F9-1F1F9|\u1F1F9-1F1FB|\u1F1F9-1F1FC|\u1F1F9-1F1FF|\u1F1FA-1F1E6|\u1F1FA-1F1EC|\u1F1FA-1F1F2|\u1F1FA-1F1F8|\u1F1FA-1F1FE|\u1F1FA-1F1FF|\u1F1FB-1F1E6|\u1F1FB-1F1E8|\u1F1FB-1F1EA|\u1F1FB-1F1EC|\u1F1FB-1F1EE|\u1F1FB-1F1F3|\u1F1FB-1F1FA|\u1F1FC-1F1EB|\u1F1FC-1F1F8|\u1F1FD-1F1F0|\u1F1FE-1F1EA|\u1F1FE-1F1F9|\u1F1FF-1F1E6|\u1F1FF-1F1F2|\u1F1FF-1F1FC|\u1F468-200D-1F468-200D-1F466|\u1F468-200D-1F468-200D-1F466-200D-1F466|\u1F468-200D-1F468-200D-1F467|\u1F468-200D-1F468-200D-1F467-200D-1F466|\u1F468-200D-1F468-200D-1F467-200D-1F467|\u1F468-200D-1F469-200D-1F466-200D-1F466|\u1F468-200D-1F469-200D-1F467|\u1F468-200D-1F469-200D-1F467-200D-1F466|\u1F468-200D-1F469-200D-1F467-200D-1F467|\u1F468-200D-2764-FE0F-200D-1F468|\u1F468-200D-2764-FE0F-200D-1F48B-200D-1F468|\u1F469-200D-1F469-200D-1F466|\u1F469-200D-1F469-200D-1F466-200D-1F466|\u1F469-200D-1F469-200D-1F467|\u1F469-200D-1F469-200D-1F467-200D-1F466|\u1F469-200D-1F469-200D-1F467-200D-1F467|\u1F469-200D-2764-FE0F-200D-1F469|\u1F469-200D-2764-FE0F-200D-1F48B-200D-1F469/g

  looseStyleTag: -> /<style/gim

  # Regular expression matching javasript function arguments:
  # https://regex101.com/r/pZ6zF0/1
  functionArgs: -> /\(\s*([^)]+?)\s*\)/

  illegalPathCharactersRegexp: ->
    #https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx
    /[\\\/:|?*><"]/g

  # https://regex101.com/r/nC0qL2/2
  signatureRegex: ->
    new RegExp(/(<br\/>){0,2}<signature>[^]*<\/signature>/)

  # Finds the start of a quoted text region as inserted by N1. This is not
  # a general-purpose quote detection scheme and only works for
  # N1-composed emails.
  n1QuoteStartRegex: ->
    new RegExp(/<\w+[^>]*gmail_quote/i)

module.exports = RegExpUtils
