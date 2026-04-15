# Mindlink
**A streamlined, zero-dependency telepathic communication ledger for Achaea and Mudlet.**

Mindlink is a modern, lightweight tell catcher, inspired by predacessors like YATCO, but simplified, streamlined, and without dependencies on other systems or packages. It captures your game's chat channels, tells, and emotes, organizing them into a clean, tabbed Geyser interface so you never lose a message to combat or travel spam again.

Unlike older systems, Mindlink has zero external dependencies, relies purely on Mudlet's native Geyser layout manager, and includes automated roleplay logging.

---

## Features

* **Zero Bloat:** Single-script architecture. No blinking timers causing lag, no reliance on legacy packages.
* **Native GMCP Routing:** Instantly captures `say`, `tell`, `party`, `city`, and other channels directly from the game's data stream.
* **Flawless Emote Capture:** Captures custom-colored emotes directly from the main window using trigger hooks, preserving the original text colors perfectly.
* **Automated RP Logging:** Silently saves clean, timestamped plain-text logs of your `Local` and `Tells` (or any other tabs you choose) directly to your computer.
* **Smart Ignore List:** Easily filter out pervasive, colored environmental text (like Hashan's leaden alchemy lines) so they don't pollute your chat tabs.

---

## Installation

1. Download the `Mindlink.mpackage` or import the `Mindlink-Core.lua` script directly into your Mudlet Script Editor.
3. Save the script. The UI will instantly generate and dock to the right side of your screen.
4. Edit the `Mindlink.config` block at the top of the script to adjust sizing, tabs, and colors to your liking.

You can put the geyser window anywhere. However, I recommend using going into Preferences > Main Display in Mudlet and adding a Display Border to the left or right in which to contain this (and possibly other packages!). I use a right border width of 650px, with my mapper above it, but this will vary based on your display size and preferences!

---

## Setting up Emote Capture

Emotes in Achaea are freeform and tricky to catch with standard text triggers. Mindlink solves this by using Achaea's native color configuration.

**Step 1:** Set your emotes to a unique color in Achaea. For example:
`config colour emotes 8`
This makes them dark grey, which is not used for very much else.

**Step 2:** Create a trigger in Mudlet to catch it:
1. Create a new trigger and change the pattern type to `color pattern`.
2. Select your chosen color (e.g., dark grey) as the foreground color.
3. In the script box, add this exact line:
   `Mindlink.captureFromTrigger("Local")`

Now, any emote painted in that color will be perfectly copied to your Local tab!

You can also use the one included with the Mudlet mpackage, or import the xml file in the repository.

*(Note: If a specific room description also uses this color, you can add that text to the `ignorePatterns` table in the script configuration to prevent it from being copied).*

---

## Accessing Your Logs

If you have logging enabled for a tab, Mindlink will organize them by date in a custom folder. 
To find your logs, open Mudlet's main input line and type:
`lua getMudletHomeDir()`

Navigate to that folder on your computer, and you will find a directory named **MindlinkLogs** containing your chat history.
