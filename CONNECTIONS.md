# Connections

A weekly word puzzle in the TMPlay tab, beside Wordle. You upload one puzzle a
week in the Firebase Console; **no app update is needed**, then or ever after.

A puzzle stays playable until you upload a newer one, so a late week never
leaves an empty screen. Readers can play each puzzle once.

## Adding this week's puzzle

**The first time only — make the folder**

1. In the Firebase Console open **Firestore Database**.
2. Click **Start collection**, type exactly `connectionsPuzzles`, then **Next**.
   You'll land on the "Add document" screen — carry on from step 4.

**Every week**

3. Open **connectionsPuzzles** and click **Add document**.
4. For **Document ID** type the date it should appear: `2026-09-23`. Four digits,
   dash, two, dash, two. Never reuse a date.
5. Add these fields:

   | Field | Type | Value |
   | --- | --- | --- |
   | `enabled` | boolean | Leave it **false** for now |
   | `startsAt` | timestamp | The same date, around 6:00 am |
   | `group1Name` | string | The **easiest** category, e.g. `BOSTON TEAMS` |
   | `group1Words` | string | `Celtics, Bruins, Sox, Patriots` |
   | `group2Name` / `group2Words` | string | Second easiest |
   | `group3Name` / `group3Words` | string | Third |
   | `group4Name` / `group4Words` | string | The trickiest |
   | `title` | string | Optional, e.g. `Puzzle No. 7` |
   | `author` | string | Optional, e.g. `Puzzle by Maya Patel` |

   Four words per group, separated by commas. **Sixteen different words in
   total** — no word may appear twice, even in another category.

   Group 1 is the easiest and group 4 the trickiest. That order is the only
   thing that chooses the colours: yellow, green, blue, purple.
6. Click **Save**.
7. **Check it before anyone sees it.** Open the app, TMPlay → Connections.
   Nothing should have changed, because `enabled` is off.
8. Set `enabled` to **true** and **Update**. Reopen the tab — your puzzle is
   there. Solve one category to confirm it accepts the answer.
9. Next week, **add a new document** with the new date. Don't edit a live
   puzzle; somebody may be midway through it.

**Getting ahead:** upload with a future date any time. It stays invisible until
that date and then takes over on its own.

**Taking one down:** set `enabled` to `false`. The app falls back to the
previous week's puzzle, never to an empty screen.

**Emergency, everywhere at once:** Remote Config → `show_connections` → `false`
→ Publish. The Connections option disappears from every open app within
seconds and TMPlay is just Wordle. Nothing is deleted.

## If your puzzle doesn't appear

The app ignores a puzzle it cannot play, and keeps showing the previous one.
Check, in this order:

- `enabled` is `true`.
- Exactly four words in each of the four groups.
- Sixteen different words — the most common mistake is the same word in two
  categories.
- All four of `group1Name` … `group4Name` are filled in.
- The document ID is a real date, or `startsAt` is set.

Then pull the TMPlay tab open again. Scheduling uses each reader's device
clock, so treat the start time as accurate to within a few hours.

## Words that are too long

Tiles are about 78 points wide on a normal iPhone. Words up to roughly eleven
characters look right; longer ones shrink and wrap. If a word has to be long,
check it on a phone before turning `enabled` on.
