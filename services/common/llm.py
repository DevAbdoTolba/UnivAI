"""LLM adapter with automatic failover (§3 of the MVP-1 prompt).

Every LLM call in the system goes through complete(). Model strings use
"provider:model" syntax so the team can swap providers by editing .env only:

    LLM_PRIMARY=gemini:gemini-2.5-flash
    LLM_FALLBACK=ollama:gemma3:4b

Rule: try PRIMARY, retry once on ANY error, then switch to FALLBACK for that
request. Always report which model actually served the request.
"""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")

TIMEOUT_S = 30


class LLMError(RuntimeError):
    pass


@dataclass
class LLMResult:
    text: str
    model_used: str  # the full "provider:model" string that actually answered


def _post_json(url: str, payload: dict, headers: dict[str, str]) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    for key, value in headers.items():
        req.add_header(key, value)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:400]
        raise LLMError(f"HTTP {exc.code}: {detail}") from exc
    except Exception as exc:  # timeouts, DNS, connection refused, bad JSON
        raise LLMError(str(exc)) from exc


def _call_gemini(model: str, system: str, prompt: str) -> str:
    key = os.getenv("GEMINI_API_KEY", "")
    if not key:
        raise LLMError("GEMINI_API_KEY is not set")
    url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent"
    )
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "systemInstruction": {"parts": [{"text": system}]},
    }
    data = _post_json(url, payload, {"x-goog-api-key": key})
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"].strip()
    except (KeyError, IndexError) as exc:
        raise LLMError(f"malformed Gemini response: {str(data)[:300]}") from exc


def _call_openai(model: str, system: str, prompt: str) -> str:
    key = os.getenv("OPENAI_API_KEY", "")
    if not key:
        raise LLMError("OPENAI_API_KEY is not set")
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": prompt},
        ],
    }
    data = _post_json(
        "https://api.openai.com/v1/chat/completions",
        payload,
        {"Authorization": f"Bearer {key}"},
    )
    try:
        return data["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError) as exc:
        raise LLMError(f"malformed OpenAI response: {str(data)[:300]}") from exc


def _call_ollama(model: str, system: str, prompt: str) -> str:
    base = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434").rstrip("/")
    payload = {
        "model": model,
        "system": system,
        "prompt": prompt,
        "stream": False,
        # Answers are <=3 spoken sentences. Uncapped generation on a busy GPU is
        # how a question turns into a 12-minute wait; keep_alive (seconds - some
        # Ollama builds 500 on the string form) stops cold-loading per question.
        "options": {"num_predict": 180},
        "keep_alive": 1800,
    }
    data = _post_json(f"{base}/api/generate", payload, {})
    text = data.get("response", "").strip()
    if not text:
        raise LLMError(f"empty Ollama response: {str(data)[:300]}")
    return text


def _dispatch(spec: str, system: str, prompt: str) -> str:
    if ":" not in spec:
        raise LLMError(f"bad model spec '{spec}' — expected provider:model")
    provider, model = spec.split(":", 1)
    provider = provider.strip().lower()
    if provider == "gemini":
        return _call_gemini(model, system, prompt)
    if provider == "openai":
        return _call_openai(model, system, prompt)
    if provider == "ollama":
        return _call_ollama(model, system, prompt)
    raise LLMError(f"unknown provider '{provider}' (use gemini|openai|ollama)")


def complete(prompt: str, system: str = "You are a helpful teaching assistant.") -> LLMResult:
    """Run a completion with primary → fallback failover. Logs which model served it."""
    primary = os.getenv("LLM_PRIMARY", "").strip()
    fallback = os.getenv("LLM_FALLBACK", "").strip()
    if not primary:
        raise LLMError("LLM_PRIMARY is not set in .env")

    errors: list[str] = []
    for spec in [s for s in (primary, fallback) if s]:
        attempts = 2 if spec == primary else 1  # primary gets one retry
        for attempt in range(attempts):
            try:
                text = _dispatch(spec, system, prompt)
                print(f"[llm] served by {spec}")
                return LLMResult(text=text, model_used=spec)
            except LLMError as exc:
                errors.append(f"{spec} (try {attempt + 1}): {exc}")
                print(f"[llm] FAILED {spec} (try {attempt + 1}): {exc}")
                if attempt + 1 < attempts:
                    time.sleep(1)

    raise LLMError("all models failed -> " + " | ".join(errors))
