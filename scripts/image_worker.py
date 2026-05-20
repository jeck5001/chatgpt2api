from __future__ import annotations

import argparse
import os

from services.image_worker_runner import ImageWorkerRunner


def main() -> None:
    parser = argparse.ArgumentParser(description="Run a ChatGPT2API distributed image worker.")
    parser.add_argument("--server", default=os.getenv("CHATGPT2API_WORKER_SERVER", "http://localhost:8000"))
    parser.add_argument("--auth-key", default=os.getenv("CHATGPT2API_AUTH_KEY", ""))
    parser.add_argument("--worker-id", default=os.getenv("CHATGPT2API_WORKER_ID", "image-worker"))
    parser.add_argument("--name", default=os.getenv("CHATGPT2API_WORKER_NAME", "Image Worker"))
    parser.add_argument("--capacity", type=int, default=int(os.getenv("CHATGPT2API_WORKER_CAPACITY", "1")))
    parser.add_argument("--poll-interval", type=float, default=float(os.getenv("CHATGPT2API_WORKER_POLL_INTERVAL", "2")))
    args = parser.parse_args()

    runner = ImageWorkerRunner(
        worker_id=args.worker_id,
        server_url=args.server,
        auth_key=args.auth_key,
        name=args.name,
        capacity=args.capacity,
        poll_interval_secs=args.poll_interval,
    )
    runner.run_forever()


if __name__ == "__main__":
    main()
