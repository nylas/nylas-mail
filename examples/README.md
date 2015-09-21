# N1 Example Packages

Here you will find well-annotated samples to showcase how to build
packages in N1.

## Getting Started

1. Each package is in its own folder. To try out a package, copy the folder
   into `$HOME/.nylas/packages`, run `apm install`, and restart N1.
2. The entry point of each package is the `activate` method of
   `lib/main.cjsx`. Most packages do nothing but register themselves with
   the `ComponentRegistry`
3. Read the annotated source code of the package files.
