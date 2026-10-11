#!/usr/bin/env bash
# Start the seeded Flask API and Vite app together for local development.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/backend"
VENV="$BACKEND/.venv"
RUN_DIR="$ROOT/.run"
mkdir -p "$RUN_DIR"

if [[ ! -x "$VENV/bin/python" ]]; then
  echo "Creating backend virtual environment..."
  python3 -m venv "$VENV"
fi
echo "Installing backend requirements..."
"$VENV/bin/pip" install -r "$BACKEND/requirements.txt"
echo "Seeding demonstration users (password printed only when first created)..."
(cd "$BACKEND" && "$VENV/bin/python" seed.py)

(
  cd "$BACKEND"
  PORT=5000 "$VENV/bin/python" app.py
) >"$RUN_DIR/backend.log" 2>&1 &
BACKEND_PID=$!
(
  cd "$ROOT/frontend"
  npm run dev -- --host 127.0.0.1
) >"$RUN_DIR/frontend.log" 2>&1 &
FRONTEND_PID=$!
cleanup() {
  echo "Stopping PeerLearn local servers..."
  kill "$BACKEND_PID" "$FRONTEND_PID" 2>/dev/null || true
  wait "$BACKEND_PID" "$FRONTEND_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "Waiting for Flask health endpoint..."
for attempt in $(seq 1 30); do
  if curl --fail --silent http://127.0.0.1:5000/api/health >/dev/null; then break; fi
  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then cat "$RUN_DIR/backend.log" >&2; exit 1; fi
  sleep 1
done
if ! curl --fail --silent http://127.0.0.1:5000/api/health >/dev/null; then
  echo "Flask did not become healthy; see $RUN_DIR/backend.log" >&2
  exit 1
fi
echo "PeerLearn is running: frontend http://127.0.0.1:5173, API http://127.0.0.1:5000/api"
echo "Logs: $RUN_DIR/frontend.log and $RUN_DIR/backend.log (press Ctrl+C to stop)"
wait
