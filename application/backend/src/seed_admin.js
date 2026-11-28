'use strict';

/** Creates the demo admin if missing. Safe to re-run. DEMO password only. */
require('dotenv').config({ quiet: true });
const bcrypt = require('bcryptjs');
const { Client } = require('pg');

async function run() {
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  try {
    const exists = await client.query("SELECT 1 FROM users WHERE email = 'admin@assessly.local'");
    if (exists.rows.length) { console.log('Admin already present.'); return; }
    const hash = await bcrypt.hash(process.env.SEED_PASSWORD || 'Demo@12345', 10);
    await client.query(
      "INSERT INTO users (email, password_hash, full_name, role) VALUES ('admin@assessly.local', $1, 'Demo Admin', 'admin')", [hash]);
    console.log('Admin created: admin@assessly.local');
  } finally {
    await client.end();
  }
}
run().catch((e) => { console.error(e.message); process.exit(1); });
