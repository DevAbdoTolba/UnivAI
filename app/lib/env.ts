import { config } from "dotenv";
import path from "path";

/**
 * The single .env lives at the repo root, one level above app/.
 *
 * Do NOT read `process.env.FOO` directly for these: the bundler inlines that
 * expression at build time, when the root .env has not been loaded yet, so it
 * compiles down to `undefined`. Read the parsed values from here instead —
 * they are resolved at runtime.
 */
const parsed =
  config({ path: path.resolve(process.cwd(), "..", ".env"), quiet: true }).parsed ?? {};

function read(name: string, fallback = ""): string {
  return parsed[name] ?? process.env[name] ?? fallback;
}

export const env = {
  DATABASE_URL: read("DATABASE_URL", "postgresql://univai:univai@localhost:5433/univai"),

  // The team's RAG service (UnivAI-Agent). This app only consumes it.
  RAG_MCP_URL: read("RAG_MCP_URL"),

  LIVEKIT_URL: read("LIVEKIT_URL") || read("NEXT_PUBLIC_LIVEKIT_URL"),
  LIVEKIT_API_KEY: read("LIVEKIT_API_KEY"),
  LIVEKIT_API_SECRET: read("LIVEKIT_API_SECRET"),
};
