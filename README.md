# aqqq.in

Source for the aq website — a bilingual (EN/JA) Hugo site.

## Development

Requires Hugo extended (v0.164.0+).

With Nix + direnv:

```
direnv allow
```

Run the dev server:

```
hugo server -D
```

Production build (outputs to `public/`):

```
hugo --minify
```

Hermetic build via Nix (outputs to `result/`, symlinked into the Nix store):

```
nix build
```
