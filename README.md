# QuestKeeper *(v.1.0.2)*

*A comprehensive quest chronicler that tracks dialogue, rewards, reputation for all discovered, accepted, completed, or abandoned quests with timestamps for each stage.*

## **WHY?**
The creation of the addon was motivated by me having to face the situation while playing WoW quite regularly: I finish the quest, head over to the NPC, click the Complete Quest button, and then find myself in situations where I have no idea what is going on, like why are the previously friendly NPCs grumpy with scarlet nameplates. While it might be that the user is to take the blame for not reading the quest details (missing out on the story of the quest, game lore) - It still happens from time to time. With this addon, the user is able to read back the details, the story of the given quest. And if I already track that much of each quest, why not satisfy the needs of a collector and track as many things regarding each quest as possible? This addon was originally meant for self-use only, but as currently no other addon offers this detailed tracking, I though others might find this helpful too. 

## **FUNCTIONALITY**

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

## **COMPATIBILITY**
* Currently only supports Game Version 12.0.5 (Midnight)

## **KNOWN ISSUES**
* Amount is not yet tracked for reward currencies
* Text does not fit in textarea when editing imported quests

## **PLANNED FEATURES**
* Independent quest tracking for separate characters, with option to combine all characters QuestKeeper database.
* Track dialogue during cutscenes
* Properly track conversations for quests that require player to talk to NPCs

## **LICENSE**
All rights reserved, for now at least.
