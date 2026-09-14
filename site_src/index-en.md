---
title: "NEXUS: Balance Realm — balance the scale, understand the algebra"
description: "A maths game for ages 9-15 · offline · no ads, no in-app purchases · Android"
---

# Balance the scale and you will understand the maths

NEXUS is an algebra game for ages **9-15** (grades 3-9) ✓✗ instead of "finish the exercise" it connects a
**physical feeling of balance** to an algebraic idea: two pans, weight, and the question "what happens if
I take this one away?" The age claim is identical across this site and the store copy, and a CI gate
checks that equality ✓ (an inconsistent age claim is not just a store rejection ✗ it contradicts the
child-facing privacy policy ✓).

## Three principles every feature is judged by
- **No punishment.** No aggressive red, no pressure timer, no "fail" ✗✓ a wrong attempt is information, not guilt.
  Pure red is banned in the whole game (Art Bible §2 ✓) and this page obeys the same rule ✓.
- **A hint is never the answer.** Aria asks and points; it never states the number ✗✓ an automated check runs that
  rule over all {{LEVELS}} levels in CI, so it is not a slogan ✓✓
- **The world mirrors the learning model.** Bridges and buildings in each region are rebuilt from the player's
  mastery ✓ progress is *seen*, not announced.

## What is in the game (and what is not)
<div class="grid">
<div class="card"><h3>{{LEVELS}} levels, 5 regions + a hub city</h3><p>From a simple balance to an equation with the unknown on both pans ✓ validated as data in CI ✓</p></div>
<div class="card"><h3>Adaptive engine</h3><p>Difficulty follows a learning curve ✓ inputs are solve time, attempt count, and hints used — never "speed score" ✗</p></div>
<div class="card"><h3>Aria, a companion — not a teacher</h3><p>Bilingual dialogue (Persian/English ✓), a template set in which none gives the answer ✓ the count lives in `docs/03` and CI — we do not type it on a marketing page ✓ ✓</p></div>
<div class="card"><h3>Real accessibility</h3><p>Colour-blind mode (pattern + colour) · text zoom ×1.25 · haptics off switch · text contrast ≥ 4.5 ✓</p></div>
<div class="card"><h3>Fully offline</h3><p>The game runs with no network ✓ cloud sync is an explicit switch and off means *no request is built at all* ✓</p></div>
<div class="card"><h3>One-time paid product</h3><p>No ads ✗ no in-app purchases ✗ no subscription ✗ (ADR-027 ✓ so no ad SDK can even be in the build — an export gate enforces that ✓)</p></div>
</div>

## The honest state of this build ⚠
<div class="status">

- ✅ game logic, {{LEVELS}} levels, accessibility, backend, {{TESTS}} automated tests, CI gates — in the repo and green ✓
- ✅ privacy policy (Persian + English) and the Families compliance checklist — published here ✓
- ⚙ Android package: the build tooling is ready ✓✗ **the real export and a phone install have not happened yet** ✓
- ⬜ screenshots and video: no engine render is possible in this repo, so **we do not fake them** ✗✓ what you see above is a concept layout, not the game
- ⬜ a human support/deletion channel: task 12.4 ✓ (must be live before release)

</div>

## For parents
- [For parents](parents.html) — what the dashboard shows, how to turn sync off, what "delete my data" means.
- [Privacy policy](privacy-en.html) · [فارسی](privacy.html) — what we collect and what we **never** collect.
- [Support](support.html) · [Feedback](feedback.html) — feedback goes to the developer, no third-party service in between ✓
