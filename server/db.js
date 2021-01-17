const Pool = require('pg').Pool;

const pool = new Pool({
    user: 'postgres',
    password: 'febrerap5',
    host: 'localhost',
    port: 5432,
    database: 'TrabajoBBDD'
});

module.exports = pool;