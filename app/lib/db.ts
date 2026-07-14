import { Pool } from "pg";
import { config } from "dotenv";
import path from "path";

// The single .env lives at the repo root, one level above app/.
config({ path: path.resolve(process.cwd(), "..", ".env"), quiet: true });

const globalForPool = globalThis as unknown as { univaiPool?: Pool };

export const pool =
  globalForPool.univaiPool ??
  new Pool({
    connectionString:
      process.env.DATABASE_URL ??
      "postgresql://univai:univai@localhost:5433/univai",
  });

if (process.env.NODE_ENV !== "production") globalForPool.univaiPool = pool;

export async function query<T extends Record<string, unknown>>(
  text: string,
  params: unknown[] = []
): Promise<T[]> {
  const res = await pool.query(text, params);
  return res.rows as T[];
}

export async function queryOne<T extends Record<string, unknown>>(
  text: string,
  params: unknown[] = []
): Promise<T | null> {
  const rows = await query<T>(text, params);
  return rows[0] ?? null;
}
