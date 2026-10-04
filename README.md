# Fluidly

A color-sorting puzzle made with [Godot 4.4](https://godotengine.org) that runs in the browser
(Web export, WebGL 2 / Compatibility renderer).

Pour colored liquids between bottles until every bottle holds a single color. Liquids never mix.

## Rules

- Each bottle holds 4 units of liquid. Every color has exactly 4 units, and there are 2 extra empty bottles.
- Tap a bottle to pick it up, then tap another bottle to pour into it.
- You can only pour onto the **same color** or into an **empty bottle**.
- A pour moves the whole top band of one color, or as much of it as fits.
- The level is complete when every bottle is either empty or full of a single color.

Levels get harder as you go, from 3 colors up to 12. Every level is generated from its number and
checked by a solver, so each level is always the same and always solvable. Your progress is saved in the browser.

## Graphics: 2D or 3D

Open **Settings** to choose the graphics:

- **2D**: flat, drawn test tubes (the default).
- **3D**: lit glass test tubes on shelves, seen through a perspective camera. The liquid surface stays
  level when a bottle tilts and sloshes when bottles are lifted, shaken or swung around. A pour shows a
  stream of liquid with a small splash.

The liquid "physics" is a shader plus a spring: the shader cuts the liquid at a plane that stays level
in world space (through the bottle axis at the fill height, which keeps the volume right for a tilted
cylinder), and a damped spring tilts that plane in response to the bottle's acceleration and rotation.
This keeps it light enough for phones and the browser. The choice is saved, and `V` switches between the
two. On the web build, `?view=3d` in the URL opens the 3D view.

## Sound

Picking up a bottle clinks, pouring bubbles (higher-pitched as the target fills up), finishing a bottle pops its
cork with a chime, and solving a level plays a short jingle. Invalid moves give a soft bonk.

All sounds are synthesized by `tools/generate_sounds.py` (Python standard library only) into `audio/`.
Edit that script and re-run it to change them:

```sh
python3 tools/generate_sounds.py
```

## Controls

| Input | Action |
| --- | --- |
| Click / tap a bottle | Pick it up, or pour the raised bottle into it |
| Undo button, `Z` or `Backspace` | Undo the last pour |
| Restart button or `R` | Restart the level |
| Hint button or `H` | Raise the bottle to pour from and highlight where to pour it |
| Settings button | Choose 2D or 3D graphics and turn sound on or off |
| `V` | Switch between 2D and 3D |
| `M` | Mute or unmute (remembered between visits) |
| `Enter` / `Space` on the win screen | Next level |

On the web build, add `?level=N` to the URL to open a specific level, for example `index.html?level=12`.

## Project layout

```
project.godot              Project settings (Compatibility renderer, "expand" stretch for any screen shape)
export_presets.cfg         "Web" export preset (single-threaded, works on any static host)
scenes/main.tscn           Game scene and HUD
scripts/puzzle.gd          Puzzle rules: pouring, win and stuck detection
scripts/solver.gd          Depth-first solver used for level validation and hints
scripts/level_generator.gd Deterministic, solvable level generation
scripts/main.gd            Game flow, input, undo, hints, settings and saving
scripts/board_view.gd      Interface between the game and its renderers
scripts/view_2d.gd         2D renderer: layout, selection and pour animations
scripts/bottle.gd          2D bottle drawing
scripts/view_3d.gd         3D renderer: shelves, lights, camera framing, hit-testing, pour animations
scripts/bottle_3d.gd       3D bottle: lathed glass and liquid meshes, slosh spring
shaders/liquid.gdshader    Level, banded liquid surface for the 3D bottles
scripts/toast.gd           Centered message bubble
scripts/sfx.gd             Sound effect playback and mute
audio/                     Generated sound effects (see tools/generate_sounds.py)
tools/generate_sounds.py   Synthesizes the sound effects
tests/run_tests.gd         Headless tests for the rules, solver and generator
.github/workflows/         CI that tests, exports and deploys to GitHub Pages
```

All graphics are drawn in code and all sounds are synthesized, so there are no external assets.

The game icon is `icon.svg` (used for the browser tab and home-screen icons). `splash.png` is the same
artwork rasterized at 256×256 for the loading screen; re-export it from `icon.svg` if you change the icon.

## Run locally

1. Install [Godot 4.4.x](https://godotengine.org/download) (standard build, not .NET).
2. Open the project (`project.godot`) in the editor and press **F5**.

## Tests

```sh
godot --headless --import
godot --headless -s res://tests/run_tests.gd
```

The script exits with the number of failed checks. It verifies the pouring rules, checks that
levels 1–30 are deterministic, use each color exactly 4 times and can be solved, and plays a pour in
both the 2D and the 3D view (including tapping every bottle).

## Export for the web

Install the matching export templates (**Editor → Manage Export Templates**), then:

```sh
mkdir -p build/web
godot --headless --export-release "Web" build/web/index.html
```

Serve the `build/web` folder with any static file server, for example:

```sh
python3 -m http.server 8060 --directory build/web
```

and open <http://localhost:8060>. The export is single-threaded, so it does not need the
`Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` headers.

## Deployment

Pushing to `main` or `master` runs `.github/workflows/deploy.yml`, which runs the tests, exports the game and
publishes it with GitHub Pages. Enable it once under **Settings → Pages → Source: GitHub Actions**.
Pull requests only run the tests and the export, to check that the project still builds.
