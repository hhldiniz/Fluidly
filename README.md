# Fluidly

A small 2D game made with [Godot 4.4](https://godotengine.org) that runs in the browser (Web export, WebGL 2 / Compatibility renderer).

You are a drop of water. Collect droplets to grow, and dodge the embers that appear as your score climbs.

## Controls

| Input | Action |
| --- | --- |
| Arrow keys / WASD | Move |
| Hold mouse button / touch | Glide toward the pointer |
| Space / Enter / click / tap | Start or restart |

The best score is stored locally in the browser.

## Project layout

```
project.godot          Godot project settings (1280x720, Compatibility renderer)
export_presets.cfg     "Web" export preset (single-threaded, works on any static host)
scenes/                main, player, droplet and hazard scenes
scripts/               GDScript for each scene
.github/workflows/     CI that exports the game and deploys it to GitHub Pages
```

All graphics are drawn in code, so there are no external assets.

## Run locally

1. Install [Godot 4.4.x](https://godotengine.org/download) (standard build, not .NET).
2. Open the project (`project.godot`) in the editor and press **F5**.

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

Pushing to `main` or `master` runs `.github/workflows/deploy.yml`, which exports the game and
publishes it with GitHub Pages. Enable it once under **Settings → Pages → Source: GitHub Actions**.
Pull requests only run the export to verify that the project still builds.
