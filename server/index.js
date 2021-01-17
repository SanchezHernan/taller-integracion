const express = require('express');
const app = express();
const cors = require('cors');
const pool = require('./db.js');

//middleware
app.use(cors());
app.use(express.json());

//Routes

//insert
app.post('/todos', async(req, res) => {
    try {
        const {description} = req.body;
        const newArticulo = await pool.query(
            'INSERT INTO DATABASE (description) VALUES($1) RETURNING *',
            [description]
        );

        res.json(newTodo.rows[0]);

    } catch (err) {
        console.error(err.message);
    }
});


//select de todos los usuarios
app.get('/usuarios', async(req, res) => {
    try {
        const usuarios = await pool.query(
            'select * from usuario');
            res.json(usuarios.rows);
    } catch (err) {
        console.error(err.message);
    }
});


//select de un usuario
app.get('/usuarios/:email', async(req, res) => {
    try {
        const { email } = req.params;
        const usuario = await pool.query(
            'select * from usuario where email = $1',
            [email]
        );
        res.json(usuario.rows[0]);
    } catch (err) {
        console.error(err.message);
    }
})

//select de un producto
app.get('/productos', async(req, res) => {
    try {
        const productos = await pool.query(
            'select * from producto');
            res.json(productos.rows);
    } catch (err) {
        console.error(err.message);
    }
});


//select de un tipo de producto
app.get('/productos/:tipo', async(req, res) => {
    try {
        const { tipo } = req.params;
        const producto = await pool.query(
            'select * from producto where tipo = $1',
            [tipo]
        );
        res.json(producto.rows);
    } catch (err) {
        console.error(err.message);
    }
})



//update
app.put('/usuarios/:email', async (req, res) => {
    try {
        const { email } = req.params;
        const { nombre } = req.body;
        const updateUser = await pool.query(
            'update usuario set nombreuser = $1 where email = $2',
            [nombre, email]
        );
        res.json('Usuario actualizado');
    } catch (err) {
        console.error(err.message);
    }
})


//delete
app.delete('usuarios/:email', async (req, res) => {
    try {
        const { email } = req.params;
        const deleteUser = await pool.query(
            'delete from usuario where email = $1',
            [email]
        );
    } catch (err) {
        console.error(err.message);
    }
})


app.listen(5000, () => {
    console.log('Server has started on port 5000');
})