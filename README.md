# QuestKeeper

## **INTRODUCTION**
The creation of the addon was motivated by the situation I have to face regularly when playing wow: Just as I finish the quest, head over to the NPC, click the Complete Quest button, and then find myself in a situation where I have no idea what is going on, and why are the previously friendly NPC grumpy with scarlet nameplates. It's a bad habit, ruins the experience and the player misses out on the lore and the humor of the game - It still happens from time to time. With this addon, the user is able to read back the details, the story of the given quest. And if I already added support for that, why not satisfy my appreciation of statistics, and track as many things regarding each quest as possible?

## **FUNCTIONALITY** *(v.1.0.0b)*:

* Tracking newly discovered, accepted, completed and abandoned quests.
* For each quest, timestamp is saved for each state.
* Introduction, In-progress and Completion dialogs are all saved automatically while the addon is enabled.
* Reward / hand in items and currencies are tracked automatically.
* Reward xp and gold is tracked automatically.
* Reputation reward is saved upon completion.
* Quests, completed without the addon being active are also partially imported and tracked - only quest id can be recovered from the game api.
* Manual editing is possible for imported quests, but not for properly tracked quests.
* Search by id, quest name and timestamp is supported.
* Order by id, quest name, quest state and timestamp is supported.
* Daily and repeatable quest are distinguished from normal quests.

## **COMPATIBILITY:**
* Currently only supports Game Version 12.0.5 (Midnight)

## **KNOWN ISSUES:**
* Amount is not yet tracked for reward currencies

## **PLANNED FEATURES**
* Independent quest tracking for separate characters, with option to combine all characters QuestKeeper database.

## **LICENSE**
All rights reserved, for now at least.
