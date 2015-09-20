# N1 Example Packages

Here you will find well-annotated samples to showcase how to build
packages in N1.

## Getting Started

1. Each package is in its own folder. Simply copy the folder you want to
   try out to `$HOME/.nylas/packages` and restart N1.
1. The entry point of each package is the `activate` method of
   `lib/main.cjsx`. Most packages do nothing but register themselves with
   the `ComponentRegistry`
1. Read the annotated source code of the package files.
