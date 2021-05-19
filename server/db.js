const user = 'postgres'
const password = 'febrerap5'
const database = 'BDVentas'

const Pool = require('pg').Pool;


const pool = new Pool({
    user: user,
    password: password,
    host: 'localhost',
    port: 5432,
    database: database
});

module.exports = pool;