# Composer Templates

Create templates you can use to pre-fill the N1 composer - never type the same
email again! Templates live in the templates folder inside the Mailspring config folder.

Each template is an HTML file - the name of the file is the name of the template,
and it's contents are the default message body.

If you include HTML &lt;code&gt; tags in your template, you can create
regions that you can jump between and fill easily.
Give &lt;code&gt; tags the `var` class to mark them as template regions. Add
the `empty` class to make them dark yellow. When you send your message, &lt;code&gt;
tags are always stripped so the recipient never sees any highlighting.

This example is a good starting point for plugins that want to extend the composer
experience.

<img src="https://raw.githubusercontent.com/nylas/nylas-mail/master/internal_packages/composer-templates/screenshot.png">
