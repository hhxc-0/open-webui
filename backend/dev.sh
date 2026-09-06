# Run relative to the backend directory so Python can import open_webui
cd "$(dirname "$0")" || exit 1

export CORS_ALLOW_ORIGIN="http://localhost:5173;http://localhost:8080"
PORT="${PORT:-8080}"
uvicorn open_webui.main:app --port $PORT --host 0.0.0.0 --forwarded-allow-ips "${FORWARDED_ALLOW_IPS:-*}" --ws-per-message-deflate "${UVICORN_WS_PER_MESSAGE_DEFLATE:-true}" --reload
