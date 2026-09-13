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

- `template.json` — static source template (metadata, icons, screenshots).
- `main.luau` — fetches the current Delta iOS `version` from `https://weao.gg/api/status/exploits`, HEADs the IPA for its `size`, and writes minified `source.json`. Run with [Lune](https://github.com/lune-org/lune) (`lune run main.luau`, pinned in `rokit.toml`).
- `source.json` — generated build artifact, committed to git (this is what preserves version history). Do not edit by hand.
- `public/` — gitignored Pages staging, regenerated on every build (`source.json` + `.nojekyll`). Uploaded as the Pages artifact, never committed.

## Known Issues

- Selene does not work at the moment for some reason, it panics when trying to lint the code.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
