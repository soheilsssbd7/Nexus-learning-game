# Privacy Policy — NEXUS: Balance Realm

**English version ✓ (Persian: `privacy-policy-fa.md` — the two files are edited together ✓ the
gate `check_privacy_policy()` compares the *lists*, so translating one side and forgetting the
other turns CI red ✓✓)**
**v1 · Owner: `soheilsssbd7` · Parent contact: ⚠ `https://<host>/contact` (filled in task 12.4 ✓
before release this link must be live ✗ otherwise Families compliance is incomplete ✓)**

Written for parents and guardians, not for children ✓ plain language, explicit lists: anything
**not** in the "never" list means it *is* collected ✓ so we kept the lists short so they stay true,
rather than pretty ✓.

## Who we are and what this app is
A maths game (balances and equilibrium) for ages 9 to 12 ✓ it works offline; one small optional
server stores **learning progress** ✓ that server is hosted by us and there is no third party in
the data path ✗ (no ads, no third-party analytics, no crash reporter ✓✓ architecture decision:
ADR-010).

## What we collect
1. **A random player identifier** ✓ — a string like `p_193f2a7e`, generated on the device ✓ it has
   no mapping to a name, a phone number, an email or a physical device ✓ (rule §2 of the technical
   doc ✓)
2. **Learning performance data** ✓ — time to solve a level, attempt counts, how many hints were
   shown, and one rating per skill (a number between 600 and 2600) ✓ these exist so the game can
   tune difficulty and so the Parent Dashboard can show them to you ✓
3. **Six learning event types, never more** ✓ — exactly: `session_start` · `session_end` ·
   `level_started` · `level_completed` · `hint_shown` · `error_occurred` ✓
   (each event = type + random id + timestamp + a few numbers ✓✗ **no text from the child** is
   ever sent ✓)
4. **A device token** ✓ — a signed string so the server knows which random id a request belongs
   to ✓ no user table, no email, no password ✓ (ADR-063)
5. **What stays on the device** ✓ — an optional display name for the profile, your volume
   settings, and the save game ✓ these are **not sent to our server** ✗✓ except the items 2 and 3
   (and the display name is never sent ✓).

## Never collected ✗
- **Real name** ✗ (only an optional display name that lives on the device ✓)
- **Email** ✗
- **Phone** ✗
- **Location** ✗ (no location permission exists in the build ✓ — checklist: `docs/families-compliance.md`)
- **Contacts** ✗
- **Camera** ✗
- **Microphone** ✗
- **IMEI** ✗
- **AAID** ✗ (the advertising id — there is no ad SDK in the app ✓)
- **MAC** ✗
- **SSID** ✗
- **BSSID** ✗
- **SIM serial** ✗
- **Device performance telemetry** ✗ (no CPU, no battery, no memory ✓ "speed" here only means how
  fast the child solved the puzzle ✓)
- **Transcribed speech, audio of the child, photos, social handles** ✗ (the app has no microphone
  and no free-text path to the server ✓)
- **Anything about the parent or guardian** ✗ (the parental panel is on-device and asks nothing of
  you ✓)

## Three things you control
1. **Cloud sync is an explicit switch** ✓ — under "Settings → Privacy", behind the parent gate ✓
   you can turn it **fully off** ✓✗ in that state the game builds no request at all (not "send
   then discard" ✗✓) and our automated test asserts exactly that ✓
2. **Delete everything** ✓ — "uninstall" or "clear app data" on Android removes the device half ✓
   for the server half, send one message to the address at the top of this document: "delete the id
   `p_…`" ✓ we can do that without knowing anything else ✓ (stateless design means deletion =
   removing rows, not searching an interconnected profile ✓)
3. **No ads, no in-app purchases** ✓ ✗ and no third-party SDKs at all ✓ (neither advertising, nor
   analytics, nor crashlytics ✓ ADR-010).

## Retention and security
- Learning events and the model live in a Postgres database we host ✓ HTTPS in the final production
  environment ✓ access only from the app ✓
- Learning events are aged out after **12 months** ✓ the *learning model* is kept, because that is
  the part that is useful to the child ✓ if you do not want it, item 2 above is what you delete ✓
- Encryption at rest: at MVP size we rely on host disk encryption ✓ daily backups follow the same
  deletion policy ✓
- Breach: if it ever happens we notify parents through that same address ✓ we cannot write "we
  would not tell you" in a policy ✓

## Younger children and consent
The game is designed for ages 9-12 ✓✗ we do not ask for an "age verification" ✗✓ because asking for
an age means collecting data ✓ instead the controls live in the parental panel ✓ if a younger child
plays, keep cloud sync off ✓

## What is **not** in this version ⚠ (honest, not a promise ✓)
- The hosted page for this document and the deletion-request form (task 12.4 ✓ until then the link
  above is a placeholder ✗)
- A web/cookie policy ✗ — there is no website; this static page is the only one ✓
- Local distribution/registration numbers (only relevant if we ship outside the Play store ✓ ADR-009)
