const mysql = require("mysql2/promise");
require("dotenv").config();

const pool = mysql.createPool({
    host: process.env.DB_HOST_PENAWARAN || process.env.DB_HOST || process.env.DB_HOST_MAIN || '127.0.0.1',
    user: process.env.DB_USER_PENAWARAN || process.env.DB_USER || process.env.DB_USER_MAIN || 'root',
    password: process.env.DB_PASSWORD_PENAWARAN || process.env.DB_PASSWORD || process.env.DB_PASSWORD_MAIN || '',
    database: process.env.DB_NAME_PENAWARAN || 'kencanaprint',
    port: Number(process.env.DB_PORT_PENAWARAN || process.env.DB_PORT || process.env.DB_PORT_MAIN || 3306),
    waitForConnections: true,
    connectionLimit: 10,
    enableKeepAlive: true,
    keepAliveInitialDelay: 10000,
});

module.exports = pool;
