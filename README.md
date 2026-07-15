# Charm's Bedtime Story Generator - CharmStory

A child-safety-aware bedtime story generator. A parent enters their child's name, characters, a setting, and a one-line plot; the app calls Google's Gemini through a hosted API, returns a short bedtime story formatted for reading aloud, and persists it so the child can re-hear yesterday's story without re-generating it. Built as the capstone of the SCTP **Bedtime Story Generator** conversion course.

## Live demo

- **Frontend:** <https://your-vercel-url.vercel.app>
- **Backend health:** <https://your-render-url.onrender.com/healthz> *(returns `{"postgres":true}`)*

> **Note on cold starts.** The backend runs on Render's free tier and spins down after 15 minutes of no traffic. The first request after a sleep takes ~30 seconds while it warms up; subsequent requests are sub-second. That's free-tier behaviour, not a bug.

## What it does

- Four-field form (child name, characters, setting, plot) → calm, child-safe bedtime story (≤5 paragraphs, addresses the child by name, no violence, gentle resolution).
- Stories are persisted to Postgres against the child's name. Click any saved story in the *"Past stories"* panel to re-hear it without paying for a new Gemini call.
- Production deploy: Vercel CDN for the static frontend, Render for the long-running FastAPI backend with managed Postgres. CORS configured to allow cross-origin requests.
- Loud-fail config — missing `GEMINI_API_KEY` or `DATABASE_URL` refuses to start, never silently runs broken.

## Stack

- **Python 3.11 + FastAPI** — backend HTTP API (3 endpoints: `POST /story`, `GET /stories`, `GET /healthz`).
- **Google Gemini API (`gemini-flash-lite-latest`)** — hosted LLM for story generation, called via the `google-genai` SDK.
- **Postgres + psycopg 3** — managed Postgres on Render; one table (`stories`) with a composite index on `(child_name, created_at DESC)`.
- **Plain HTML + CSS + vanilla JS** — no framework, no build step. Three static files served from Vercel.
- **Render + Vercel** — backend on Render (Blueprint deploy from `render.yaml`), frontend on Vercel (static deploy from `vercel.json`).

## Run it locally

Requires Python 3.11+, Postgres, and a free Google AI Studio API key (<https://aistudio.google.com/apikey>).

```bash
# Run startup environment setup and checks
chmod +x run.sh     #required only the first time
./run.sh

# Option FastAPI server on :8000
uvicorn app.main:app --reload
