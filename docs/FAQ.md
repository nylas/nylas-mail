---
Title:   FAQ
Section: Guides
Order:   10
---

### Do I have to use React?

The short answer is yes, you need to use React. The {ComponentRegistry} expects React components, so you'll need to create them to extend the Nylas Mail interface.

However, if you have significant code already written in another framework, like Angular or Backbone, it's possible to attach your application to a React component. See [https://github.com/davidchang/ngReact/issues/80](https://github.com/davidchang/ngReact/issues/80).

### Can I write a package that does X?

If you don't find documentation for the part of Nylas Mail you want to extend, let us know! We're constantly working to enable new workflows by making more of the application extensible.

### Can I distribute my package?

Yes! We'll be sharing more information about publishing packages in the coming months. However, you can already publish and share packages by following the steps below:

1. Create a Github repository for your package, and publish a `Tag` to the repository matching the version number in your `package.json` file. (Ex: `0.1.0`)

2. Make the CURL request below to the package manager server to register your package:

        curl -H "Content-Type:application/json" -X POST -d '{"repository":"https://github.com/<username>/<repo>"}' https://edgehill-packages.nylas.com/api/packages

3. Your package will now appear when users visit the Nylas Mail settings page and search for community packages.

Note: In the near future, we'll be formalizing the process of distributing packages, and packages you publish now may need to be resubmitted.
