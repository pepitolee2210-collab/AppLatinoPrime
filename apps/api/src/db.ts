import pg, { type QueryResultRow } from "pg";
import { config } from "./config";

const { Pool } = pg;

export const pool = config.DATABASE_URL
  ? new Pool({
      connectionString: config.DATABASE_URL,
      max: 20,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 5_000
    })
  : null;

export async function query<T extends QueryResultRow = QueryResultRow>(sql: string, params: unknown[] = []): Promise<T[]> {
  if (!pool) {
    return [];
  }

  const result = await pool.query<T>(sql, params);
  return result.rows;
}
