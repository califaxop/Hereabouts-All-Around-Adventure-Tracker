# Changelog

## 1.7.0 (Milestone 1: reliability and data integrity)

- Fixed: "Quests this session (~N to level)" used each quest's money reward as its XP.
- Fixed: "Reset to defaults" didn't reset the "hide in combat / in dungeons" choices, the session
  stats shown or the border colour (changing them changed the defaults too).
- Fixed: in combat, a quest item button could end up beside another quest when the list changed
  (a quest finished, a section hidden in combat, a scroll). Such a button now dims, its tooltip
  says which quest it's for, and it moves back beside its quest when combat ends.
- Fixed: Quests Nearby could miss a change in Questie's available quests and not update.
- The session survives damaged saved data (it starts afresh instead), and XP across more than one
  level-up at once is marked approximate ("~").
- Gold in the session bar is "gold gained": money in, spending not taken off (the labels say so).
- Errors are shown once and kept: `/hab errors`. New: `/hab status`.

Earlier versions: see "Recent changes" in README.md.
