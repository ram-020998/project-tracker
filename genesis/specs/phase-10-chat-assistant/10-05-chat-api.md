# 10-05 — Chat API + SSE

**Repo:** `genesis` · **Ships with:** v0.19.0 · **Depends on:** 10-04 · **Blocks:** 10-06

## 1. Objective

Expose the `ChatManager` over HTTP under `/api/chat/*` (ADR-028), including the streaming turn
endpoint, and wire the manager into `create_app`.

## 2. Current state (verified)

- `genesis/api/app.py` `create_app(manager, settings, source_factory)` builds a `RunManager`,
  `ConfigService`, mounts all routes on `APIRouter(prefix="/api")`, then the SPA fallback. FastAPI
  version string currently `"0.18.0"`.
- SSE precedent — `events_stream`: `EventSourceResponse(gen())`, replay the durable log after
  `after`, then tail `manager.cbus(run_id).subscribe()` via `asyncio.to_thread(next, sub, None)`,
  emitting `{"event": kind, "data": json}` (NAMED events) with seq dedupe. **Mirror this** for the
  chat turn stream (chat's stream is per-turn and closes on `agent.result`/`error`, so no durable
  replay is needed — the transcript is fetched separately via GET session).
- Pydantic body models (`StartRun`, etc.) + `HTTPException` error style.

## 3. Design

### 3.1 Instantiate the manager

In `create_app`: `chat = ChatManager(settings, config)` (reuse the same `ConfigService`). Add an app
shutdown hook (`@app.on_event("shutdown")` or lifespan) to `await chat.aclose_all()`.

### 3.2 Routes (on the `/api` router)

```
GET    /api/chat/sessions                       -> [ {id,title,created_at,updated_at,message_count} ]
POST   /api/chat/sessions            {title?}    -> {id}
GET    /api/chat/sessions/{id}                   -> {session, messages:[{seq,role,content,events,ts}]}
PATCH  /api/chat/sessions/{id}       {title}     -> {ok}
DELETE /api/chat/sessions/{id}                   -> {ok}
POST   /api/chat/sessions/{id}/messages {text}   -> text/event-stream (the turn)
POST   /api/chat/sessions/{id}/cancel            -> {ok}
```

- 404 if session unknown (a `_require_session` helper mirroring `_require`).
- `messages`: validate `text` non-empty and `len ≤ settings.chat_max_prompt_chars` (400 otherwise);
  if a turn is already active on the session, return **409**. Otherwise return
  `EventSourceResponse(gen())` where `gen()` iterates `chat.stream_turn(id, text)` and yields
  `{"event": ev["type"], "data": json.dumps(ev)}` for each event until the terminal
  `agent.result`/`error`, then stops (closing the stream).
- The web client POSTs and reads the SSE body via `fetch` + a stream reader (EventSource can't POST)
  — see 10-06. Set `Cache-Control: no-transform` headers (sse-starlette handles framing).

### 3.3 Body models

`CreateSession{title: str = "New chat"}`, `RenameSession{title: str}`, `SendMessage{text: str}`.

## 4. Files to touch

- `genesis/genesis/api/app.py` — instantiate `ChatManager`; add the chat routes on the `/api`
  router; shutdown hook; bump the FastAPI version to `0.19.0`.
- `genesis/genesis/api/chat.py` (optional) — factor the chat routes into a helper that registers on
  the router (keep `app.py` readable), following the `studio.py` split precedent.
- `genesis/tests/test_chat_api.py` (new).

## 5. Tests / DoD

- Use FastAPI `TestClient` with a `ChatManager` whose client factory is the **fake** from 10-04
  (scripted messages). Assert:
  - session CRUD (create/list/get/rename/delete) status + shapes;
  - `POST /messages` returns an event-stream whose parsed events are the scripted `agent.*` ending in
    `agent.result` (TestClient can read the streamed body);
  - empty/oversized `text` → 400; a second concurrent turn → 409; unknown session → 404;
  - `DELETE` cascades (subsequent GET → 404) and closes the live session;
  - `cancel` → 200 and terminates the stream.
- pytest + ruff green; the existing api tests unaffected.

## 6. Risks

- Streaming under `TestClient` — sse-starlette works with `TestClient.stream`/reading the response
  body; if awkward, test `chat.stream_turn` directly for event content and the route for status
  codes. Keep the SSE contract identical to `events_stream` so the web reader (10-06) is uniform.
- Long-lived SSE + shutdown: ensure the generator exits on `agent.result`/`error` and on client
  disconnect (sse-starlette cancels the generator on disconnect — release the session lock in a
  `finally`).
