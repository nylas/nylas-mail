module.exports = {
  A: {
    id: 1,
    accountId: 'test-account-id',
    subject: "Loved your work and interests",
    body: "<head></head><body>Hi Jackie,<div><div>While browsing Nylas&nbsp;themes, I stumbled upon your website and looked at your work.&nbsp;</div><div>Great work on projects, nice to see your multidisciplinary interests :)</div><div><div><br></div><!-- <signature> -->Thanks,&nbsp;<div>Sagar Sutar</div><div>thesagarsutar.me</div><!-- </signature> --></div></div><img class=\"n1-open\" width=\"0\" height=\"0\" style=\"border:0; width:0; height:0;\" src=\"https://link.nylas.com/open/8w734mdm7q9ivpc0cnq3ousy3/local-7b7d5479-575c?r=amFja2llaGx1b0BnbWFpbC5jb20=\"></body>",
    headers: {
      "Delivered-To": "jackiehluo@gmail.com",
      "Received-SPF": `pass (google.com: domain of sagy26.1991@gmail.com
        designates 209.85.192.174 as permitted sender) client-ip=209.85.192.174;`,
      "Authentication-Results": `mx.google.com;
         spf=pass (google.com: domain of sagy26.1991@gmail.com designates
         209.85.192.174 as permitted sender) smtp.mailfrom=sagy26.1991@gmail.com`,
      "X-Google-DKIM-Signature": `v=1; a=rsa-sha256; c=relaxed/relaxed;
          d=1e100.net; s=20130820;
          h=x-gm-message-state:date:user-agent:message-id:to:from:subject
           :mime-version;
          bh=to3fCB9g4R6V18kpAAKSAlUeTC+N0rg4JckFbiaILA4=;
          b=WfI5viTYPjviUur9Bd2rJQfpHxIm2xYRdxrN64bJGuX0TQlb7p8bDvCBNNhY3mTXJx
           lsQzRX9RA4FMuDk0oz0mpviWtkpkZsDeyjpSmA+ONcPgdyPAezzPDvSWRzMZY21fiHxS
           hr4I5AeFKesGcbvwtJu+S0fMGhdveC8E35oTA010Xfave6Xd55qGXy7hW+4xCfvIesy4
           01oOaXWDmLHqixKO3SXwmGCcDzqn/IKXhB7UXkF0efSTwh8yid6v9iXdW+ovJ2qg9peI
           HSnPIilYk8SaKoPdGDgYZykfUIgNrSugtK/vvGG2aN+9lhURxPfzhniWdNqdsgR7G4E7
           7XqA==`,
      "X-Gm-Message-State": "ALyK8tIf7XyYaylyVf0qjzh8rhYz3rj/VQYaNLDjVq5ESH19ioJIgW7o9FbghP+wFYrBuw==",
      "X-Received": `by 10.98.111.138 with SMTP id k132mr3246291pfc.105.1466181525186;
          Fri, 17 Jun 2016 09:38:45 -0700 (PDT)`,
      "Return-Path": "<sagy26.1991@gmail.com>",
      "Received": `from [127.0.0.1] (ec2-52-36-99-221.us-west-2.compute.amazonaws.com. [52.36.99.221])
          by smtp.gmail.com with ESMTPSA id d69sm64179062pfj.31.2016.06.17.09.38.44
          for <jackiehluo@gmail.com>
          (version=TLS1_2 cipher=ECDHE-RSA-AES128-GCM-SHA256 bits=128/128);
          Fri, 17 Jun 2016 09:38:44 -0700 (PDT)`,
      "Date": "Fri, 17 Jun 2016 09:38:44 -0700 (PDT)",
      "User-Agent": "NylasMailer/0.4",
      "Message-Id": "<82y7eq1ipmadaxwcy6kr072bw-2147483647@nylas-mail.nylas.com>",
      "X-Inbox-Id": "82y7eq1ipmadaxwcy6kr072bw-2147483647",
    },
    from: [{
      name: "Sagar Sutar",
      email: "<sagar_s@nid.edu>",
    }],
    to: [{
      name: "jackiehluo@gmail.com",
      email: "<jackiehluo@gmail.com>",
    }],
    cc: [],
    bcc: [],
    headerMessageId: "<82y7eq1ipmadaxwcy6kr072bw-2147483647@nylas-mail.nylas.com>",
    snippet: "Hi Jackie, While browsing Nylas themes, I stumbled upon your website and looked at your work. Great ",
  },
  B: {
    id: 2,
    accountId: 'test-account-id',
    subject: "Re: Loved your work and interests",
    body: "<head></head><body>Sagar,<div><div><br></div><div>Aw, glad to hear it! Thanks for getting in touch!</div><br><!-- <signature> -->Jackie Luo<div>Software Engineer, Nylas</div><br><!-- </signature> --></div><div class=\"gmail_quote\">On Jun 17 2016, at 9:38 am, Sagar Sutar &lt;sagar_s@nid.edu&gt; wrote:<br><blockquote class=\"gmail_quote\" style=\"margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;\">Hi Jackie,<div><div>While browsing Nylas&nbsp;themes, I stumbled upon your website and looked at your work.&nbsp;</div><div>Great work on projects, nice to see your multidisciplinary interests :)</div><div><div><br></div>Thanks,&nbsp;<div>Sagar Sutar</div><div>thesagarsutar.me</div></div></div><img width=\"0\" height=\"0\" style=\"border:0; width:0; height:0;\" src=\"https://link.nylas.com/open/8w734mdm7q9ivpc0cnq3ousy3/local-7b7d5479-575c?r=amFja2llaGx1b0BnbWFpbC5jb20=\"></blockquote></div></body>",
    headers: {
      "Date": "Fri, 17 Jun 2016 18:20:47 +0000",
      "References": "<82y7eq1ipmadaxwcy6kr072bw-2147483647@nylas-mail.nylas.com>",
      "In-Reply-To": "<82y7eq1ipmadaxwcy6kr072bw-2147483647@nylas-mail.nylas.com>",
      "User-Agent": "NylasMailer/0.4",
      "Message-Id": "<cq08iqwatp00kai4qnff7zbaj-2147483647@nylas-mail.nylas.com>",
      "X-Inbox-Id": "cq08iqwatp00kai4qnff7zbaj-2147483647",
    },
    from: [{
      name: "Jackie Luo",
      email: "<jackiehluo@gmail.com>",
    }],
    to: [{
      name: "Sagar Sutar",
      email: "<sagar_s@nid.edu>",
    }],
    cc: [],
    bcc: [],
    headerMessageId: "<cq08iqwatp00kai4qnff7zbaj-2147483647@nylas-mail.nylas.com>",
    snippet: "Sagar, Aw, glad to hear it! Thanks for getting in touch! Jackie Luo Software Engineer, Nylas",
  },
};
