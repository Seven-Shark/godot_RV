# AGENTS.md instructions for D:\Godot\godot-RV

## Game Design Discussion

跟我讨论游戏的时候，不要估计我的感受，不要照顾我的情绪。你是专业的游戏设计师，必须站在游戏设计、可玩性、市场性、用户的角度分析。如果我说的不合理，要直接提出反驳。

## Multi-Device Codex Workflow

This project may be edited from multiple devices and multiple Codex sessions. Do not treat chat history as the source of truth. Recover context from repository files before making assumptions.

### Shortcut Commands

If the user says "读取交接文档", "按项目交接流程启动", or any close equivalent, treat it as a request to run the full project handoff startup flow:

1. Read `AGENTS.md`.
2. Read `docs/CODEX_HANDOFF.md`.
3. Read `docs/Game_Design_Document.md`.
4. Run `git status --short`.
5. Run `git log --oneline -5`.
6. Continue according to the rules in this file.

### Before Starting Work

1. Check the local worktree:
   - `git status --short`
   - `git log --oneline -5`
2. Read these files before changing code or design docs:
   - `AGENTS.md`
   - `docs/Game_Design_Document.md`
   - `docs/CODEX_HANDOFF.md`
3. If network/Git access is available and the user has not asked to avoid it, sync with the shared remote before starting:
   - `git pull`
4. If there are uncommitted changes you did not make, preserve them. Do not revert or overwrite them unless the user explicitly asks.

### During Work

1. Keep each task scoped to one clear area when possible.
2. Avoid parallel edits to high-conflict Godot files across devices:
   - `.tscn`
   - `.tres`
   - `project.godot`
   - shared data tables and large UI scenes
3. Long-term design decisions belong in `docs/Game_Design_Document.md`.
4. Short-term progress, blockers, risks, and next steps belong in `docs/CODEX_HANDOFF.md`.
5. For Godot implementation, keep existing project boundaries:
   - player input logic belongs in `GameInputEvents` where applicable
   - `SurvivalScene` and `HomeScene` responsibilities should not be mixed casually
   - avoid hardcoding final UI/game text in scripts; reserve final text for the future shared language table path
   - prefer reusable bridge/coordinator scripts or managers over hidden cross-system coupling

### Before Finishing Work

1. Update `docs/CODEX_HANDOFF.md` with:
   - what changed
   - files changed
   - verification performed
   - open risks or blockers
   - the next suggested step
2. Report how the user should see the changes in Godot Editor:
   - `.gd`: refresh/rerun the scene
   - `.tscn`: reopen the scene and choose Reload if prompted
   - `.tres`: refresh and check dependent resources
   - imported assets: reimport if needed
   - `project.godot`: restart Godot
3. If a commit is requested, commit only the intended files and leave unrelated changes untouched.
