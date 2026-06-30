# On-device image generation for scene & creature visuals

**Status:** Design (brainstorm) — approved decisions captured; pending plan.
**Date:** 2026-06-30
**Predecessor:** [`procedural-level-generation-design.md`](2026-06-30-procedural-level-generation-design.md) §11 (the `SceneVisualProvider` seam this fills).

## 1. Summary

Enrich the game's themed visuals with **on-device generated images** using iOS 26's **Image Playground `ImageCreator`** API. Generated images appear in two places only: **bestiary creature portraits** and **between-levels cut-scene art**. The live in-game reveal stays the existing animated, `stir`-driven procedural background (a static image can't ramp with stir, so it is intentionally untouched), and level-select stays text. Every generated image is produced **once per id**, cached to disk, and is a pure **enrichment**: the existing asset-free procedural rendering is the universal fallback, so the app looks complete on every device (and in the simulator/CI, where Image Playground is unavailable).

## 2. Decisions (from brainstorm)

- **Engine:** Image Playground `ImageCreator` (programmatic, on-device). Chosen over Core ML Stable Diffusion (which would add 1–2 GB app size and ~20–30 s/image) and over "bundled art only".
- **Placement:** bestiary portraits + cut-scene art. **Not** the gameplay reveal background; **not** level-select thumbnails.
- **Fallback:** the existing procedural rendering (silhouettes / gradient scenes), not bundled static art — keeps the project asset-free and guarantees coverage on non-Apple-Intelligence devices.

## 3. Goals / non-goals

**Goals**
- A `SceneVisualProvider` seam that turns a (scene|creature) id + theme into an image, on-device, cached per id.
- Graceful degradation: unavailable engine, content refusal, timeout, or simulator → procedural fallback, never a blank.
- IP-free, guardrail-safe themed prompts (mood over monsters) derived from the curated `ThemePools.zenDoom` slugs.
- Keep prompt mapping pure and unit-tested; keep the iOS-only `ImageCreator` code in the app target.

**Non-goals**
- Replacing the animated gameplay reveal; level-select thumbnails.
- Core ML / Stable Diffusion; networked generation.
- Cross-device-identical images (Image Playground output isn't seed-reproducible across OS versions — cache the first generation as canonical).

## 4. Architecture & module boundaries

`ImageCreator` is iOS-only, so the provider lives in the **app target**. The **prompt table is pure data** (keyed by the `ThemePools.zenDoom` slugs) and lives in **`LevelGen`** so a test guarantees every slug has a prompt.

```
LevelGen (pure, tested)
  VisualPrompts            // slug + theme → IP-free prompt string; promptVersion

App target (iOS-only)
  SceneVisualProvider      // protocol: async image(for: VisualRequest) -> CGImage?
  VisualRequest            // (id, theme, kind: .scene/.creature)
  ImagePlaygroundVisualProvider  // ImageCreator-backed; availability-gated
  VisualCache              // disk PNG cache keyed by id+kind+style+promptVersion
  GeneratedImageView       // SwiftUI: async cache→generate, procedural fallback
  ProceduralPortrait       // asset-free fallback portrait (reuses silhouette/palette)
```

`GeneratedImageView` is the single integration primitive: given a `VisualRequest` and a `@ViewBuilder` fallback, it shows the fallback immediately, asynchronously resolves the image (cache hit → instant; miss → generate + cache), and cross-fades it in when ready. Views (bestiary, cut scene) just place a `GeneratedImageView`.

## 5. Generation pipeline

`image(for: VisualRequest) async -> CGImage?`:
1. **Cache check** — `VisualCache.image(forKey:)` (`"<id>-<kind>-<style>-v<promptVersion>"`). Hit → return.
2. **Availability** — lazily `try await ImageCreator()`. Throws on unsupported devices (this is the availability check; there is no `isAvailable` flag). On throw → return `nil` (caller shows procedural fallback). Cache the unavailable state for the session to avoid repeated throws.
3. **Style** — read `creator.availableStyles`; prefer `.illustration`, else `.animation`, else the first available.
4. **Prompt** — `VisualPrompts.prompt(for: request)` → `ImagePlaygroundConcept.text(prompt)`.
5. **Generate** — `creator.images(for: [concept], style: style, limit: 1)`; take the first streamed element's `.cgImage`. Wrap in a **timeout** (e.g. 20 s); on timeout/empty/error → `nil`.
6. **Downscale** to the display size (≤512²), **store** PNG via `VisualCache`, return.

Generation is kicked off lazily by `GeneratedImageView` when it appears — never on the gameplay hot path. Pre-generation of the next cut scene MAY be added later; not required.

## 6. Content & prompt strategy

Image Playground silently refuses photorealistic/violent/scary/IP content and skews stylized. Prompts therefore lean on **mood, color, and abstract/architectural subjects**, never named IP (no "Cthulhu"/"Doomguy"/"Buffy") or gore. `VisualPrompts` maps each curated slug to a short prompt, e.g.:
- `still-pond` → "a calm koi pond at dawn, soft mist, pastel illustration"
- `sunken-crypt` → "an ancient overgrown stone crypt at night, faint green glow, stylized illustration"
- `deep-tentacle` → "a coiling deep-sea tentacle creature, teal and violet, eerie bioluminescent glow, stylized"
- `koi-spirit` → "a serene glowing koi spirit, soft watercolor, calm"

A `promptVersion` integer invalidates the cache when prompts change. Unknown slugs fall back to a theme-templated generic prompt (zen = calm/nature, doom = ominous/ruin) so the table never hard-fails. The pure test asserts every `ThemePools.zenDoom` scene+creature slug yields a non-empty prompt and contains no banned IP tokens.

## 7. Caching & stability

`VisualCache` writes PNGs to `Caches/visuals/`. Generation runs once per key; replays read the cache. Because output isn't reproducible across OS versions, the **first generation is canonical** (cache-aggressively). A cache miss simply regenerates (if available) or shows the fallback. Caches are disposable (system may purge `Caches/`) — that's fine, they regenerate.

## 8. Availability & fallback

- No Apple Intelligence (device ineligible / disabled / model not ready) or **simulator** → `ImageCreator()` throws → provider returns `nil` → `GeneratedImageView` shows the procedural fallback. The app is fully playable and themed without ever generating an image.
- This makes the procedural fallback the path exercised by `xcodebuild`/CI and most test devices; the generated path is verified manually on an Apple-Intelligence device.

## 9. Integration points

- **BestiaryView** — each *revealed* creature row shows `GeneratedImageView(.creature, id, theme: .doom)` with a `ProceduralPortrait` fallback; hidden creatures keep the redacted silhouette.
- **CutSceneView** — a `GeneratedImageView(.scene, …)` becomes the **base layer** under the existing animated ripples/vignette/creature (fallback = current gradient scene). Optionally the popped-out creature uses `GeneratedImageView(.creature, …)` scaled/opacity-driven by the existing `doom` value (fallback = current silhouette). The poem, timing, accessibility, and reduced-doom/motion behavior are unchanged.

## 10. Risk: `ImageCreator` API status

WWDC26 de-emphasizes the programmatic `ImageCreator` in favor of UI sheet APIs unsuitable for silent per-id generation. **Plan task 1 is a compile/availability probe** against the iOS 26.5 SDK. If `ImageCreator` is unavailable or hard-deprecated, the `SceneVisualProvider` seam + procedural fallback still ship (the app degrades gracefully to today's behavior) and the engine decision is revisited — no rework of the integration. This is why the seam + fallback are built first and the `ImageCreator` provider plugs in behind them.

## 11. Testing

- **Pure (`swift test`):** `VisualPrompts` — every `ThemePools.zenDoom` slug → non-empty, IP-safe prompt; `promptVersion` present; deterministic.
- **App (`xcodebuild`):** compiles; the procedural-fallback path renders (the only path available in the simulator). `VisualCache` key/round-trip is lightly testable.
- **Manual (device):** generated images appear and cache, on an Apple-Intelligence iPhone.
