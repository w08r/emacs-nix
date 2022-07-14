# Quirky Nix derivation for Emacs on MacOS

Around the time of native compilation being not quite available on
master and also slightly later some shenanigans around vfork on mac,
noticed the emacs performance was considerably improved by building
off the gccjit branch with a vfork patch and with the apple compiler
rather than the default nix gcc which is somewhat older.

Started building a nix derivation to be able to always build from
master, also include compilation of vterm and pdftools as they seemed
fiddly to build outside the nix build context.

To use this, just clone the repo, then runt the following:

```
nix-env build default.nix
```

This should leave an emacs build in `./result`.  If that seems good, then

```
nix-env -f default.nix -i w08r-emacs
rm result
```
