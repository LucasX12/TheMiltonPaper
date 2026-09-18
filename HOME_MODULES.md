# Front-page modules

Modules are extra blocks on the **Today** page — a "Senior of the Week" box, a
spotlight, a row of cards — that live in Firebase rather than in the app. You
add, change and retire them in the Firebase Console. **None of it needs an app
update**: readers see the change the next time they open Today or pull down to
refresh.

At most **three** modules show at once (lowest `order` wins), and each row holds
at most **12** cards.

## Where they appear

By default a module sits **below This Week's Issue and above Latest**, so the
lead story and the two stories under it are never pushed down. Setting
`placement` to `top` puts it above the lead instead — keep that for something
genuinely more important than the day's lead story.

## Adding "Senior of the Week"

Do this at [console.firebase.google.com](https://console.firebase.google.com) in
the **the-milton-paper-3f71c** project. There's a shortcut in the app under
You → Staff Dashboard → Firebase Console.

**The first time only — make the folder**

1. In the left sidebar click **Firestore Database**.
2. Click **Start collection**.
3. For Collection ID type exactly `homeModules`, then **Next**. You'll land on
   the "Add document" screen — carry on from step 5.

**Every time**

4. Click the **homeModules** column, then **Add document**.
5. For Document ID type `senior-of-the-week`. (Only for the very first one —
   after that you *edit* this same document each week instead of making a new
   one. Skip to step 9.)
6. Add the fields below. For each: click **Add field**, type the name, pick the
   type from the dropdown, type the value.

   | Field | Type | Value |
   | --- | --- | --- |
   | `type` | string | `spotlight` |
   | `title` | string | `Maya Patel` |
   | `subtitle` | string | `Senior of the Week` |
   | `body` | string | One to three sentences about her. |
   | `imageURL` | string | The photo's web address, starting with `https://` |
   | `linkURL` | string | The full story's address on themiltonpaper.com |
   | `order` | number | `10` |
   | `enabled` | boolean | Leave it **false** for now |

   Spelling matters: `type` must be exactly `spotlight`, all lowercase.
7. Click **Save**.
8. **Check it before anyone sees it.** Open the app and pull down on Today to
   refresh — nothing should appear yet, because `enabled` is off. Now set
   `enabled` to **true** in the console and **Update**. Pull to refresh again;
   the box should be there. Tap it and confirm the link goes where you meant.
9. Next week, open the same `senior-of-the-week` document and change `title`,
   `subtitle`, `body`, `imageURL` and `linkURL`. Leave `type`, `order` and
   `enabled` alone.

**Taking it down:** set `enabled` to `false`. The box disappears and the text
stays for next time. Don't delete the document.

**Scheduling it:** add `startsAt` and/or `endsAt` as type **timestamp**. The box
appears and retires on its own. Both are optional — leave them off if unsure.

## Adding a row of cards

Same as above with `type` set to `rail`, and `title` is the row's heading
("Spring Sports"). Then, inside that document, click **Start collection**, name
it exactly `items`, and add one document per card:

| Field | Type | Required | Value |
| --- | --- | --- | --- |
| `title` | string | yes | The card's heading |
| `order` | number | yes | Left-to-right position (10, 20, 30…) |
| `subtitle` | string | no | A second line |
| `imageURL` | string | no | `https://…` |
| `linkURL` | string | no | Where tapping the card goes |

## All module fields

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `type` | string | ✅ | `spotlight` or `rail` |
| `title` | string | ✅ | Spotlight headline, or the row's heading |
| `enabled` | boolean | ✅ | `false` hides it and keeps the content |
| `order` | number | ✅ | Lower shows first. Use 10, 20, 30 so you can insert between |
| `subtitle` | string | — | Small label above the title |
| `body` | string | — | Description. Spotlight only |
| `imageURL` | string | — | `https://…`. Spotlight only |
| `linkURL` | string | — | Where tapping goes |
| `actionLabel` | string | — | Button text. Defaults to "Read more" |
| `placement` | string | — | `afterIssue` (default) or `top` |
| `startsAt` | timestamp | — | Stay hidden until then |
| `endsAt` | timestamp | — | Disappear at that moment |

## If something looks wrong

- **The module isn't showing.** Check `enabled` is `true`, `type` is spelled
  exactly right, and you don't already have three modules with a lower `order`.
  Then pull down on Today to refresh.
- **The image or link is ignored.** Addresses must start with `https://`. The
  app deliberately drops anything else.
- **You need it gone right now, everywhere.** In **Remote Config**, set
  `show_home_modules` to `false` and publish. Every open app clears its modules
  within seconds, and nothing is deleted — set it back to `true` to restore.

Scheduling uses each reader's device clock, so treat `startsAt` / `endsAt` as
accurate to within a few hours, not to the minute.
