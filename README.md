# Mindlink
**A streamlined, zero-dependency telepathic communication (tells, channels, etc.) ledger for Achaea and Mudlet.**

Mindlink is a modern, lightweight tell catcher, inspired by predacessors like YATCO, but simplified, streamlined, and without dependencies on other systems or packages. It captures your game's chat channels, tells, and emotes, organizing them into a clean, tabbed Geyser interface so you never lose a message to combat or travel spam again.

Unlike older systems, Mindlink has zero external dependencies, relies purely on Mudlet's native Geyser layout manager, and includes automated roleplay logging.

---

## Features

* **Zero Bloat:** Single-script architecture. No blinking timers causing lag, no reliance on legacy packages.
* **Native Multi-Line GMCP Routing:** Instantly captures `say`, `tell`, `party`, `city`, and other channels directly from the game's data stream, perfectly reconstructing messages split by Achaea's internal line breaks.
* **Mathematical Highlighting:** Highlights custom words, names, and phrases natively in your main window without destroying your prompt or overwriting Achaea's native ANSI colors. 
* **Automated Emote Capture:** Captures custom-colored emotes directly from the main window, preserving the original text colors perfectly. Mindlink manages the triggers and server configurations for this completely automatically!
* **Automated RP Logging:** Silently saves clean, timestamped plain-text logs of your `Local` and `Tells` (or any other tabs you choose) directly to your computer.
* **Smart Ignore List:** Easily filter out pervasive, colored environmental text (like Hashan's leaden alchemy lines) so they don't pollute your chat tabs.
* **Profile Sharing:** Export your color setups, tab names, and highlights to a JSON file to easily share your setup with friends or alt characters!

---

## Installation

1. Download the `Mindlink.mpackage` or import the `Mindlink-Core.lua` script directly into your Mudlet Script Editor.
2. Save the script. The UI will instantly generate and dock to the right side of your screen.
3. Edit the `Mindlink.config` block at the top of the script to adjust sizing, tabs, and colors to your liking.
4. Type `mindlink help` in the game for a list of helpful commands!

You can put the geyser window anywhere. However, I recommend going into Preferences > Main Display in Mudlet and adding a Display Border to the left or right in which to contain this (and possibly other packages!). I use a right border width of 650px, with my mapper above it, but this will vary based on your display size and preferences!

---

## Catching Emotes (Zero Setup!)

Emotes in Achaea are freeform and tricky to catch with standard text triggers. Mindlink solves this by using Achaea's native color configuration—and it does all the heavy lifting for you.

When you install Mindlink, the script automatically talks to Achaea to set your emote color to dark grey (XTerm 242) and silently builds the Mudlet trigger to catch it. **You do not need to make any manual triggers.** If you want to change the color used to catch emotes:
1. Type `COLOURS` in Achaea to find an XTerm256 color number you like.
2. Open the Mindlink script and change `emoteColor = 242` to your new number.
3. Save the script. Mindlink will instantly sync with Achaea and rebuild its internal triggers!

*(Note: If a specific room description also uses this color, you can add that text to the `ignorePatterns` table in the script configuration to prevent it from being copied).*

---

## Accessing Your Logs & Profiles

If you have logging enabled for a tab, Mindlink will organize them by date in a custom folder. 

To find your logs and your exported JSON profiles, open Mudlet's main input line and type:
`lua getMudletHomeDir()`

Navigate to that folder on your computer, and you will find a directory named **Mindlink**. Inside, you will see your `Mindlink_Profile.json` configuration file, as well as a **Logs** folder containing your chat history.
