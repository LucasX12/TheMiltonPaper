# Editorial controls

The app reads these Boolean parameters from Firebase Remote Config. Every
parameter also defaults to `true` in the app, so a missing value or an offline
launch never removes content unexpectedly.

| Parameter | Controls |
| --- | --- |
| `show_this_week` | This Week section |
| `show_tmplay` | TMPlay section |
| `show_student_reflections` | Student Reflections tab, carousel, and stories |
| `show_faculty_farewells` | Faculty Farewells tab and stories |
| `show_news` | News section and stories |
| `show_opinion` | Opinion section and stories |
| `show_sports` | Sports section and stories |
| `show_aande` | A&E section and stories |
| `show_editorial` | Editorial section and stories |

## One-time Firebase setup

1. Open the `the-milton-paper-3f71c` project in Firebase Console.
2. Open **Remote Config** and create each parameter above as a Boolean.
3. Set every default value to `true` and publish the configuration.
4. Confirm the **Firebase Remote Config Realtime API** is enabled if Firebase
   prompts for it.

After this app version is released, change a parameter to `false` and publish
to remove that section. Open apps receive the change through the real-time
listener; offline apps continue using their last activated configuration.

Remote Config values are public to the app. Use them only for presentation and
feature availability, never for API keys or other secrets.
