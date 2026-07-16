# Spikes

Time-boxed investigation records — a spike answers a specific, load-bearing question with
real evidence before we commit to building. Each spike is throwaway *code* but a durable
*document*: what we asked, how we tested it, what we found, and the recommendation.

(Larger phase-level findings still live in `progress/`; ADRs in `reference/decision-log.md`.
This folder is for focused feasibility probes.)

| Date | Spike | Verdict |
|---|---|---|
| 2026-07-16 | [Kiro Skills over ACP (chat priority)](2026-07-16-kiro-skills-in-acp-and-chat.md) | ✅ Skills work over ACP (filesystem `.kiro/skills/`, not the MCP wire); auto-activation + `/skill` both fire. Chat is the priority-1 target. |
