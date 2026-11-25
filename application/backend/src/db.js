'use strict';

const { Pool } = require('pg');
const config = require('./config');

/** Shared connection pool. Keep it small: dev machine has 8 GB RAM. */
const pool = new Pool({ connectionString: config.databaseUrl, max: 5 });

module.exports = { pool, query: (text, params) => pool.query(text, params) };
