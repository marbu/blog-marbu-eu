---
title: Getting started with Hakyll on Fedora
tags: fedora, haskell
...

[Hakyll](https://jaspervdj.be/hakyll/) is a *static-site generator* written in
haskell, inspired by other such tools like
[Jekyll](https://en.wikipedia.org/wiki/Jekyll_(software)),
[nanoc](https://nanoc.ws/) or [yst](https://github.com/jgm/yst). It uses
haskell DSL for configuration in a similar way how
[xmonad](https://xmonad.org/) does, and for html building, it relies on
versatile [pandoc](https://pandoc.org/) document converter.

Reasons I use Hakyll to build my personal blog include:

- I simply prefer static-site generator approach for this use case, it allows
  me to write posts in a simple plain text format and then store them in a git
  repository.
- I already use pandoc for various tasks (converting between wiki formats,
  generating epub files, exporting my markdown or org mode notes ...) because
  it can convert between lot of markup and document formats. Possibility to use
  pandoc features in hakyll makes all these familiar possibilities available,
  which is a plus.
- I'm little familiar with haskell and as xmonad user, I find xmonad's approach
  to configuration flexible and powerful.

## Installing Hakyll on Fedora

Fortunately Hakyll is already packaged in Fedora, so we don't need to build it
themselves via `cabal` or `stack` just to have it installed if we don't have
other reason to do so (eg. using latest version of hakyll for testing or
development of hakyll itself).

The package we need to install is `ghc-hakyll-devel`:

```
# dnf install ghc-hakyll-devel
```

And everything else will be installed as a dependency. Installing the devel
package is necessary because Hakyll's reconfiguration process includes haskell
compilation.

## Initializing Hakyll project

First of all, we are going to use `hakyll-init` tool to create new directory
`example-site` with both content and configuraion files of the example project:

```
$ hakyll-init example-site
Creating example-site/templates/post-list.html
Creating example-site/templates/post.html
Creating example-site/templates/default.html
Creating example-site/templates/archive.html
Creating example-site/index.html
Creating example-site/images/haskell-logo.png
Creating example-site/site.hs
Creating example-site/contact.markdown
Creating example-site/css/default.css
Creating example-site/about.rst
Creating example-site/posts/2015-10-07-rosa-rosa-rosam.markdown
Creating example-site/posts/2015-08-12-spqr.markdown
Creating example-site/posts/2015-11-28-carpe-diem.markdown
Creating example-site/posts/2015-12-07-tu-quoque.markdown
Creating example-site/example-site.cabal
$ cd example-site
```

Now we need to compile `site.hs`, which is haskell source code file with hakyll
configuration for the site, into `site` binary file:

```
$ ghc --make site.hs
[1 of 1] Compiling Main             ( site.hs, site.o )
Linking site ...
```

We could also use `cabal` instead as explained in upstream [hakyll installation
tutorial](https://jaspervdj.be/hakyll/tutorials/01-installation.html), but
since we have Hakyll installed from the rpm package, we already have all the
devel dependencies installed as well, and there is no need to use cabal just
for building of the `site` executable.

The resulting `site` tool then provides all hakyll's functionality:

```
$ ./site -h
Usage: site [-v|--verbose] COMMAND
  site - Static site compiler created with Hakyll

Available options:
  -h,--help                Show this help text
  -v,--verbose             Run in verbose mode

Available commands:
  build                    Generate the site
  check                    Validate the site output
  clean                    Clean up and remove cache
  deploy                   Upload/deploy your site
  preview                  [DEPRECATED] Please use the watch command
  rebuild                  Clean and build again
  server                   Start a preview server
  watch                    Autocompile on changes and start a preview server.
                           You can watch and recompile without running a server
                           with --no-server.
```

When we check the size of the executable, we see that it's quite large. That is
because like golang, haskell compiler uses static linking. From the system
perspective, the executable is dynamically linked though. If the size is
bothering us, we can try to stripe the binary to save about 25% of the
executable size.

```
$ ls -lh site
-rwxrwxr-x. 1 martin martin 148M Mar 28 19:13 site
$ strip site
$ ls -lh site
-rwxrwxr-x. 1 martin martin 110M Mar 28 19:47 site
```

## Building the example site

So now we can generate html files of the site via:

```
$ ./site build
Initialising...
  Creating store...
  Creating provider...
  Running rules...
Checking for out-of-date items
Compiling
  updated templates/default.html
  updated about.rst
  updated templates/post.html
  updated posts/2015-08-12-spqr.markdown
  updated posts/2015-10-07-rosa-rosa-rosam.markdown
  updated posts/2015-11-28-carpe-diem.markdown
  updated posts/2015-12-07-tu-quoque.markdown
  updated templates/archive.html
  updated templates/post-list.html
  updated archive.html
  updated contact.markdown
  updated css/default.css
  updated images/haskell-logo.png
  updated index.html
Success
```

And check the result in `_site/` directory. We can also start hakyll preview
http server which will present the site on <http://127.0.0.1:8000> and auto
recompile html files when it's source files changes:

```
$ ./site watch
Listening on http://127.0.0.1:8000
Initialising...
  Creating store...
  Creating provider...
  Running rules...
Checking for out-of-date items
Compiling
Success
```

## Next steps

As noted above, the configuration of a hakyll project is done via `site.hs`
file, which contains haskell source code. Domain specific language approach
combined with good upstream
[tutorials](https://jaspervdj.be/hakyll/tutorials.html) and [real world
examples](https://jaspervdj.be/hakyll/examples.html)
makes
changing hakyll configuration possible even without fully understanding
haskell language, but having some haskell knowledge will definitelly help a
lot.
And as you have most likely already guessed, when you update configuration in
`site.hs` file, you need to recompile `site` executable.
