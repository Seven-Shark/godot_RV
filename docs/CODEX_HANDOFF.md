# Codex Handoff

## Purpose

This file is the short-term handoff point for multi-device Codex development. Keep durable design rules in `docs/Game_Design_Document.md`; keep temporary progress and next-step context here.

## Current Focus

- Establishing a reliable multi-device workflow so Codex sessions on different machines can recover project context without relying on chat history.

## Last Completed

- Added root-level `AGENTS.md` as the standard entry point for Codex sessions working in `D:\Godot\godot-RV`.
- Added this handoff file as the short-term state log for current progress, blockers, risks, and next suggested work.
- Added a shortcut command rule: when the user says "读取交接文档" or "按项目交接流程启动", Codex should run the full startup flow from `AGENTS.md`.

## Files Changed In Latest Handoff

- `AGENTS.md`: repository-wide Codex instructions, including game-design critique posture, startup checks, multi-device sync rules, and Godot-specific refresh notes.
- `docs/CODEX_HANDOFF.md`: short-term handoff template and current context.

## Required Startup Context For Future Codex Sessions

Before making changes, read:

1. `AGENTS.md`
2. `docs/Game_Design_Document.md`
3. `docs/CODEX_HANDOFF.md`
4. Recent Git history with `git log --oneline -5`
5. Current worktree state with `git status --short`

If Git remote access is available, sync before starting with `git pull`, unless the user asks not to or the local worktree has uncommitted changes that need review first.

Shortcut command the user can type in a new Codex session:

```text
读取交接文档
```

This means: read `AGENTS.md`, `docs/CODEX_HANDOFF.md`, `docs/Game_Design_Document.md`, check `git status --short`, check `git log --oneline -5`, then continue according to `AGENTS.md`.

## Open Decisions

- Decide whether every substantial Codex task should also append a short entry to `.trae/rules/project-rv-diary.md`, or whether that diary should remain a separate manual/Trae-specific record.
- Decide whether `docs/Game_Design_Document.md` should replace its current embedded "current conversation handoff prompt" with a shorter pointer to this file.

## Known Risks

- Multiple devices editing Godot scene/resource files at the same time can cause hard-to-merge conflicts, especially `.tscn`, `.tres`, and `project.godot`.
- A Codex session that only reads chat history can miss newer design or code decisions made from another device.
- Running `git pull` with uncommitted local edits can create avoidable conflicts; check `git status --short` first.

## Next Suggested Step

- On the next feature or design task, start by reading the required startup context above, then update this file at the end of the task with the concrete changes, verification, and next step.

## Latest Verification

- Worktree was clean before these handoff files were added.
- Recent commits checked with `git log --oneline -5`.
- No Godot scenes, scripts, resources, or project settings were modified by this handoff setup.
