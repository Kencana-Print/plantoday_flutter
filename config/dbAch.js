const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
    host: process.env.DB_HOST_ACH || process.env.DB_HOST || '127.0.0.1',
    user: process.env.DB_USER_ACH || process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD_ACH || process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME_ACH || 'kpi',
    port: Number(process.env.DB_PORT_ACH || process.env.DB_PORT || 3306),
    waitForConnections: true,
    connectionLimit: 10,
    enableKeepAlive: true,
    keepAliveInitialDelay: 10000,
});

module.exports = pool;
