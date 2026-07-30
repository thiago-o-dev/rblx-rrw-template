# rblx-rrw-template
Template for quick start with roblox luau game development using Rokit, Rojo and Wally

# Auto generated:
Generated manually for usage with [Rojo](https://github.com/rojo-rbx/rojo) 7.6.1. (rollback from 7.7.0 as it's broken)

## Getting Started
This rojo implementation is not actually keeping track of non script instances (as setting up the git LFS would be complicated), the game assets are kept in the actual game place.
Do not build from scratch.

First install the dependencies:
```bash
rokit install
```
```bash
wally install
```
```bash
rojo sourcemap default.project.json --output sourcemap.json
```
```bash
wally-package-types --sourcemap sourcemap.json Packages/
```


Then, just start the Rojo server:

```bash
rojo serve
```

And open the specific place in Roblox Studio.

For more help, check out [the Rojo documentation](https://rojo.space/docs).
