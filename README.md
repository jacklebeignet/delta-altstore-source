<img src="./assets/project-icon-transparent.png" alt="Project Logo" width="256" height="256">

# delta-altstore-source

Auto-updating AltStore / SideStore source for Delta (iOS), hosted with GitHub Pages.

Add this source URL in your installer:

```text
https://jacklebeignet.github.io/delta-altstore-source/source.json
```

`source.json` is rebuilt automatically every 6 hours by GitHub Actions (see `.github/workflows/update.yml`). New versions are prepended, history accumulates, nothing is overwritten.

> [!WARNING]
> **Unofficial project. Not affiliated with, endorsed by, or connected to Delta (`deltaexploits.gg`) or its developers in any way.**
>
> **We do not host any Delta files.** This repository only contains a JSON source file that links to the official CDN download URL (`cdn.glopdelivery.com`). All app binaries, trademarks, and rights belong to their respective owners. If you are a rights holder and have an issue with a link, contact the file host. There is nothing hosted here to take down.

## How it works

- `template.json`: static source template (metadata, icons, screenshots). Image URLs point at our own Pages `assets/` (see below).
- `assets/`: vendored images committed to git (`logo.webp`, `icon.png`, `screenshot1-4.png`, `project-icon*.png`), originally curled from `cdn.weao.gg` / `imgur` (`project-icon*` are ours: README branding and the source icon). Self-hosting so the source doesn't depend on third-party hotlinking.
- `main.luau`: scrapes the current Delta iOS `version` from the official site (`deltaexploits.gg`, `.dev` mirror as fallback, `weao.gg` API as last resort), HEADs the IPA for its `size`, rewrites all image URLs to the Pages base URL (from `PAGES_BASE_URL` or `GITHUB_REPOSITORY`, fallback to this repo), stages `assets/` → `public/assets/`, and writes minified `source.json` plus a `public/index.html` redirect to the repo. Run with [Lune](https://github.com/lune-org/lune) (`lune run main.luau`, pinned in `rokit.toml`).
- `source.json`: generated build artifact, committed to git (this is what preserves version history). Do not edit by hand.
- `public/`: gitignored Pages staging, regenerated on every build (`source.json` + `assets/` + `index.html` redirect + `.nojekyll`). Uploaded as the Pages artifact, never committed.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
