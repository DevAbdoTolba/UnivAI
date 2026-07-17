"""LLM adapter. Every LLM call in the system goes through complete().

Model strings use "provider:model" syntax so the team can swap providers by
editing .env only. Providers: ollama | gemini | openai | groq | grok | bedrock
(openai/groq/grok/bedrock also take a *_BASE_URL for compatible gateways).

    LLM_PRIMARY=ollama:gemma3:1b
    LLM_FALLBACK=                      # optional — empty means one model, no net

Rule: try PRIMARY, retry once on ANY error, then switch to FALLBACK if one is
set. Always report which model actually served the request.
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

# A spoken answer (<=180 tokens) must fail FAST into the fallback; a course
# generation call (~1600 tokens on a small local model) legitimately takes
# minutes. 30s on the long calls meant every attempt died mid-generation.
TIMEOUT_QA_S = 30
TIMEOUT_GENERATION_S = 600


class LLMError(RuntimeError):
    pass


@dataclass
class LLMResult:
    text: str
    model_used: str  # the full "provider:model" string that actually answered


def _post_json(url: str, payload: dict, headers: dict[str, str], timeout: float) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    for key, value in headers.items():
        req.add_header(key, value)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:400]
        raise LLMError(f"HTTP {exc.code}: {detail}") from exc
    except Exception as exc:  # timeouts, DNS, connection refused, bad JSON
        raise LLMError(str(exc)) from exc


def _call_gemini(
    model: str, system: str, prompt: str, max_tokens: int | None, timeout: float
) -> str:
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
    if max_tokens:
        payload["generationConfig"] = {"maxOutputTokens": max_tokens}
    data = _post_json(url, payload, {"x-goog-api-key": key}, timeout)
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"].strip()
    except (KeyError, IndexError) as exc:
        raise LLMError(f"malformed Gemini response: {str(data)[:300]}") from exc


def _call_openai_style(
    base: str,
    key_env: str,
    model: str,
    system: str,
    prompt: str,
    max_tokens: int | None,
    timeout: float,
) -> str:
    """The chat-completions dialect OpenAI popularized — Groq, xAI and most
    gateways speak it too, so one core serves them all."""
    key = os.getenv(key_env, "")
    if not key:
        raise LLMError(f"{key_env} is not set")
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": prompt},
        ],
    }
    if max_tokens:
        payload["max_tokens"] = max_tokens
    data = _post_json(
        f"{base.rstrip('/')}/chat/completions",
        payload,
        {"Authorization": f"Bearer {key}"},
        timeout,
    )
    try:
        return data["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError) as exc:
        raise LLMError(f"malformed response from {base}: {str(data)[:300]}") from exc


def _call_openai(
    model: str, system: str, prompt: str, max_tokens: int | None, timeout: float
) -> str:
    # Any OpenAI-compatible gateway (a course sandbox, a proxy) plugs in here.
    base = os.getenv("OPENAI_BASE_URL", "") or "https://api.openai.com/v1"
    return _call_openai_style(base, "OPENAI_API_KEY", model, system, prompt, max_tokens, timeout)


def _call_groq(
    model: str, system: str, prompt: str, max_tokens: int | None, timeout: float
) -> str:
    base = os.getenv("GROQ_BASE_URL", "") or "https://api.groq.com/openai/v1"
    return _call_openai_style(base, "GROQ_API_KEY", model, system, prompt, max_tokens, timeout)


def _call_grok(
    model: str, system: str, prompt: str, max_tokens: int | None, timeout: float
) -> str:
    base = os.getenv("XAI_BASE_URL", "") or "https://api.x.ai/v1"
    return _call_openai_style(base, "XAI_API_KEY", model, system, prompt, max_tokens, timeout)


def _call_bedrock(
    model: str, system: str, prompt: str, max_tokens: int | None, timeout: float
) -> str:
    """Amazon Bedrock's Converse API with a Bedrock API key (Bearer auth).

    Model IDs look like 'us.meta.llama3-3-70b-instruct-v1:0' or
    'openai.gpt-oss-120b-1:0' — the catalog a sandbox key lists."""
    key = os.getenv("BEDROCK_API_KEY", "") or os.getenv("AWS_BEARER_TOKEN_BEDROCK", "")
    if not key:
        raise LLMError("BEDROCK_API_KEY is not set")
    region = os.getenv("BEDROCK_REGION", "us-east-1")
    base = os.getenv(
        "BEDROCK_BASE_URL", f"https://bedrock-runtime.{region}.amazonaws.com"
    ).rstrip("/")
    from urllib.parse import quote

    url = f"{base}/model/{quote(model, safe='')}/converse"
    payload = {
        "messages": [{"role": "user", "content": [{"text": prompt}]}],
        "system": [{"text": system}],
        # Converse has no small default cap; an uncapped spoken answer is a
        # 12-minute wait wearing a different provider's hat.
        "inferenceConfig": {"maxTokens": max_tokens or 300},
    }
    data = _post_json(url, payload, {"Authorization": f"Bearer {key}"}, timeout)
    try:
        parts = data["output"]["message"]["content"]
        text = "".join(part.get("text", "") for part in parts).strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise LLMError(f"malformed Bedrock response: {str(data)[:300]}") from exc
    if not text:
        raise LLMError(f"empty Bedrock response: {str(data)[:300]}")
    return text


def _call_ollama(
    model: str, system: str, prompt: str, max_tokens: int | None, timeout: float
) -> str:
    base = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434").rstrip("/")
    options: dict = {"num_predict": max_tokens or 180}
    if max_tokens:
        # Generation calls (slides, quizzes) carry pages of book text; the
        # default 4k window would silently truncate the prompt. They also need
        # valid JSON back, which a small model produces far more reliably cold.
        options["num_ctx"] = 8192
        options["temperature"] = 0.4
    payload = {
        "model": model,
        "system": system,
        "prompt": prompt,
        "stream": False,
        # Answers are <=3 spoken sentences. Uncapped generation on a busy GPU is
        # how a question turns into a 12-minute wait; keep_alive (seconds - some
        # Ollama builds 500 on the string form) stops cold-loading per question.
        "options": options,
        "keep_alive": 1800,
    }
    data = _post_json(f"{base}/api/generate", payload, {}, timeout)
    text = data.get("response", "").strip()
    if not text:
        raise LLMError(f"empty Ollama response: {str(data)[:300]}")
    if max_tokens and data.get("done_reason") == "length":
        # Generation callers need complete JSON; a reply cut at the token cap
        # can never parse, so say so instead of letting them puzzle over it.
        print(f"[llm] WARNING: {model} hit the {max_tokens}-token cap (reply truncated)", flush=True)
    return text


def _dispatch(
    spec: str,
    system: str,
    prompt: str,
    max_tokens: int | None,
    timeout_s: float | None = None,
) -> str:
    if ":" not in spec:
        raise LLMError(f"bad model spec '{spec}' — expected provider:model")
    timeout = timeout_s or (TIMEOUT_GENERATION_S if max_tokens else TIMEOUT_QA_S)
    provider, model = spec.split(":", 1)
    provider = provider.strip().lower()
    if provider == "gemini":
        return _call_gemini(model, system, prompt, max_tokens, timeout)
    if provider == "openai":
        return _call_openai(model, system, prompt, max_tokens, timeout)
    if provider == "groq":
        return _call_groq(model, system, prompt, max_tokens, timeout)
    if provider in ("grok", "xai"):
        return _call_grok(model, system, prompt, max_tokens, timeout)
    if provider == "bedrock":
        return _call_bedrock(model, system, prompt, max_tokens, timeout)
    if provider == "ollama":
        return _call_ollama(model, system, prompt, max_tokens, timeout)
    raise LLMError(
        f"unknown provider '{provider}' (use ollama|gemini|openai|groq|grok|bedrock)"
    )


def complete(
    prompt: str,
    system: str = "You are a helpful teaching assistant.",
    max_tokens: int | None = None,
    force_spec: str | None = None,
    timeout_s: float | None = None,
) -> LLMResult:
    """Run a completion with primary → fallback failover. Logs which model served it.

    force_spec skips the failover order and asks exactly that model — used when a
    caller has decided the primary's OUTPUT (not its availability) is the problem."""
    primary = os.getenv("LLM_PRIMARY", "").strip()
    fallback = os.getenv("LLM_FALLBACK", "").strip()
    if not primary and not force_spec:
        raise LLMError("LLM_PRIMARY is not set in .env")

    specs = [force_spec] if force_spec else [s for s in (primary, fallback) if s]
    errors: list[str] = []
    for spec in specs:
        attempts = 2 if spec == primary else 1  # primary gets one retry
        for attempt in range(attempts):
            try:
                text = _dispatch(spec, system, prompt, max_tokens, timeout_s)
                print(f"[llm] served by {spec}", flush=True)
                return LLMResult(text=text, model_used=spec)
            except LLMError as exc:
                errors.append(f"{spec} (try {attempt + 1}): {exc}")
                print(f"[llm] FAILED {spec} (try {attempt + 1}): {exc}", flush=True)
                if attempt + 1 < attempts:
                    time.sleep(1)

    raise LLMError("all models failed -> " + " | ".join(errors))
