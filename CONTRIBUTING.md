# Contributing

Thanks for helping make Git Manager better.

## Setup

```bash
swift build
swift test
./scripts/build-app.sh
```

## Guidelines

- Use [Conventional Commits](https://www.conventionalcommits.org): `feat:`, `fix:`, `docs:`, `refactor:`, `perf:`, `chore:`. Release notes are generated from them.
- Keep files small and focused. Split views before they reach ~500 lines.
- Prefer `struct`/`enum` types, dictionary mapping over `switch`, and early returns.
- No code comments: name things so they explain themselves.
- Use SF Symbols for icons, never emoji in the UI.
- Every user-facing string goes through `L("key")` and must exist in both `en.lproj` and `pt-BR.lproj`.
- Never send a secret anywhere unencrypted.

## Video

```bash
cd video
npm install
npm run studio
npm run render
```

If Remotion's bundled Chrome fails to start, pass `--browser-executable="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"`.
