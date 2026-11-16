# Coach View Plan

What we're changing in the coach side of TracKing, what's done, and what might come next.
Goal: make it easy for one coach to time reps for several groups running at once and start rest with one tap.

Mockups and the original proposal: https://claude.ai/artifact/MK8ZjWM2gnLmEMk3D8Lh2a

Out of scope for now: Firestore sync, importing workouts, editing workouts.

---

## In progress (this branch)

### Workout tab
- The coach's first tab is now **Workout** (was "Today").
- Top of the screen: the day's session, with arrows to move between days.
- A **Timing / Plan** switch:
  - **Timing** opens the Track Board.
  - **Plan** shows one group's full plan (warm-up, drills, notes, every set) with a group picker. Tapping a rep still opens the old stopwatch, which is now where you review, fix, or retime a rep's times.

### Track Board
- One card per group practicing that day. Each card has its own clock, so several groups can run at once.
- Each card has one big button that changes with the group's state:
  - **Ready**: big green **GO**. There's also a **Rest** button for reps the coach watches but doesn't time.
  - **Running**: live clock and a big **Finish** button (tap once per athlete crossing). **Undo**, **Tie**, and **End Rep** are underneath. The rep ends by itself when everyone is in.
  - **Resting**: rest starts by itself, counted from the last finisher. Countdown with **+30s** and **Skip**. It turns gold in the last 10 seconds.
  - **On the line**: a gold outline when rest is over, so you know which group to send.
  - **Done**: "All reps timed".
- Taps record on touch-down, not release, so finish times are as accurate as possible.
- The card menu has: Focus, Go to Rep (jump to any rep, for example to retime one), Time Athletes Separately, Return to Group, Separate Groups (for combined groups), and Cancel Rep.
- Every group has a lane number and color that are also used on the lock screen.

### Focus mode
- Opened from a card's menu. One group fills the screen with a large Finish pad.
- The other groups shrink to a strip across the top. The strip still shows their clocks and rests, and has its own **GO**, so the coach can send another group without leaving the finish they're watching.

### Naming times
- During a rep the coach only taps Finish. Names get matched up afterward, usually during rest.
- A **Name N times** button shows on the card for each rep that hasn't been named yet.
- In the naming sheet, tap names in the order they finished. Each name goes on the fastest time that doesn't have a name yet. Tap a name that's already on a time to take it back off. There's no swapping.
- **Same Order as Last Rep** fills in every name with one tap, when the order didn't change.
- **Later** keeps the times waiting. **Discard Times** throws them away (for false starts).

### Time athletes separately (day groups)
- From a card's menu, choose **Time Athletes Separately**, then pick athletes, for example Brandon and Justin practicing at a different time.
- They get their own card, marked "Today only", for that session. Their usual group keeps going without them.
- Their times go on the same workout, so they can finish it later that day. Come back to the Workout tab and their card will be on the next rep they haven't run.
- **Return to Group** on their card puts them back in their usual group. Times they already logged stay.
- A day group can mix event groups. Each athlete only runs the sets meant for their own group.

### Lock screen rest
- A Live Activity shows every running clock and rest countdown on the lock screen and in the Dynamic Island. The group due back on the line soonest is listed first.
- A notification goes off when each rest ends ("Long Sprints: on the line"), even with the phone locked. The app asks for notification permission the first time GO is tapped.
- This adds a new widget extension target (`TracKingWidgets`) and a `Shared` folder that both the app and the extension compile.

---

## Known limits right now
- Live timing state (running clocks, rests, and times that haven't been named yet) is kept in memory. If the app is force-quit mid-practice, those are lost. Saved times are kept.
- Lane colors follow the order of groups on the board, so a color can shift when a day group is added.
- The project file was edited by hand to add the widget extension. If Xcode has trouble opening it, see "If the widget target won't build" below.

## If the widget target won't build
1. In Xcode, delete the `TracKingWidgetsExtension` target.
2. Use File > New > Target > Widget Extension, name it `TracKingWidgets`, and check "Include Live Activity".
3. Delete the template files Xcode creates, and add the files in `TracKingWidgets/` and `Shared/` to the new target.
4. Make sure `Shared/TrackBoardActivity.swift` is in both the app and the widget target.
5. In the app target's Info, set "Supports Live Activities" (`NSSupportsLiveActivities`) to YES.

---

## Maybe next
- **GO both**: one button to start two groups that are both on the line.
- **Rest alerts at 0:30 and 0:10**, with a sound option (a whistle).
- **Keep live state through a relaunch**: save running clocks, rests, and times waiting for names.
- **iPad layout**: cards two or three across.
- **Hardware button or Apple Watch for Finish**, so the coach can keep their eyes on the line. Needs a quick test first.
- **Groups**: set up the main groups as Men's Short Sprints, Women's Short Sprints, Men's Long Sprints, and Women's Long Sprints (Team tab > Event Groups).
- **Later**: Firestore sync (so assistants can time too and athletes see their times), importing workouts, editing workouts.

## Open questions
- How do groups usually start: does the coach say "go" and tap at the same time, or start the clock when they see the group move?
- Phone only, or iPad too?
- Will anyone else time (for example an assistant on hurdles)?
