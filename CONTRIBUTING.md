# Filing an Issue

Thanks for checking out Nylas Mail! If you have a feature request, be sure to check out the [open source roadmap](http://trello.com/b/hxsqB6vx/n1-open-source-roadmap). If someone has already requested
the feature you have in mind, you can upvote the card on Trello—to keep things organized, we
often close feature requests on GitHub after creating Trello cards.

If you've found a bug, try searching for similars issue before filing a new one. Please include
the version of Nylas Mail you're using, the platform you're using (Mac / Windows / Linux), and the
type of email account. (Gmail, Outlook 365, etc.)

# Pull requests

We require all authors sign our [Contributor License
Agreement](https://www.nylas.com/cla.html) before pull requests (even
minor ones) can be accepted. (It's similar to other projects, like NodeJS
Meteor, or React). I'm really sorry, but Legal made us do it.

### Commit Format

We decided to not impose super strict commit guidelines on the community.

We're trusting you to be thoughtful, responsible, committers.

We do have a few heuristics:

- Keep commits fairly isolated. Don't jam lots of different functionality
  in 1 squashed commit. `git bisect` and `git cherry-pick` should still be
  reasonable things to do.
- Keep commits fairly significant. DO `squash` all those little file
  changes and "fixmes". Don't make it difficult to browse our history.
  Play the balance between this idea and the last point. If a commit
  doesn't deserve your time to write a long thoughtful message about, then
  squash it.
- Be hyper-descriptive in your commit messages. I care less about what
  you did (I can read the code), **I want to know WHY you did it**. Put
  that in the commit body (not the subject). Itemize the major semantic
  changes that happened.
- Read "[How to Write a Git Commit Message](http://chris.beams.io/posts/git-commit/)" if you haven't already (but don't be too prescriptivist about it!)
