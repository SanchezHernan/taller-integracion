const express = require('express');
const app = express();
const cors = require('cors');
const pool = require('./db.js');

app.use(cors());
app.use(express.json());



//GETS

//select de todos los usuarios
app.get('/usuarios', async(req, res) => {
    try {
        const usuarios = await pool.query(
            'select * from usuario');
            res.json(usuarios.rows);
    } catch (err) { console.error(err.message) }
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
    } catch (err) { console.error(err.message) }
})

//select de un producto
app.get('/productos', async(req, res) => {
    try {
        const productos = await pool.query(
            'select * from producto order by codigo');
            res.json(productos.rows);
    } catch (err) { console.error(err.message) }
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
    } catch (err) { console.error(err.message) }
})

//select un producto
app.get('/producto/:codigo', async(req, res) => {
    try {
        const { codigo } = req.params;
        const producto = await pool.query(
            'select * from producto where codigo = $1',
            [codigo]
        );
        res.json(producto.rows);
    } catch (err) { console.error(err.message) }
})

app.get('/producto/calificable/:prodId/:usuario', async(req, res) => {
    try {
        const { prodId, usuario } = req.params;
        const estado = 'FINALIZADA'
        const resp = await pool.query(
            'select $1 in (select producto from linea where carrito in (select carrito from compra where usuario = $2 and estado = $3) and producto is not null union select distinct producto from productoxcombo where combo in (select combo from linea where carrito in (select carrito from compra where usuario = $2 and estado = $3) and combo is not null)) as calificable',
            [ prodId, usuario, estado ]
        );
        res.json(resp.rows[0]);
    } catch (err) { console.error(err.message) }
});

//select de las ofertas
app.get('/ofertas', async(req, res) => {
    try {
        const producto = await pool.query(
            'select * from producto where porcDescuento > 0'
        );
        res.json(producto.rows);
    } catch (err) { console.error(err.message) }
})

//select productos en carrito
app.get('/carrito/productos/:cartId', async(req, res) => {
    try {
        const {cartId} = req.params;
        const productos = await pool.query(
            'select p.nombre, p.precio, p.porcdescuento, l.cantidadproducto, l.codigo from producto p, linea l where p.codigo = l.producto and l.carrito = $1 union select c.nombre, c.precio, 0 as porcdescuento, l.cantidadproducto, l.codigo from combo c, linea l where c.codigo = l.combo and l.carrito = $1',
            [cartId]
        );
        res.json(productos.rows);
    } catch (err) { console.error(err.message) }
})

app.get('/miscompras/:email', async(req, res) => {
    try {
        const {email} = req.params;
        const miscompras = await pool.query(
            'select l.codigo, l.cantidadproducto, l.carrito, p.nombre, p.codigo as prodId, co.total, co.fecha, co.estado, false as iscombo from linea l, compra co, producto p where l.carrito in (select carrito from compra where usuario = $1) and p.codigo = l.producto and l.carrito = co.carrito union select l.codigo, l.cantidadproducto, l.carrito, c.nombre, c.codigo as prodId, co.total, co.fecha, co.estado, true as iscombo from linea l, compra co, combo c where l.carrito in (select carrito from compra where usuario = $1) and c.codigo = l.combo and l.carrito = co.carrito',
            [email]
        );
        res.json(miscompras.rows);
    } catch (err) { console.error(err.message) }
})

app.get('/combos', async(req, res) => {
    try {
        const combos = await pool.query(
            'select * from combo order by codigo');
        res.json(combos.rows);
    } catch (err) { console.error(err.message) }
});

app.get('/combo/productos/:comboId', async(req, res) => {
    try {
        const {comboId} = req.params;
        const resp = await pool.query(
            'select * from productoxcombo pc, producto p where pc.producto = p.codigo and pc.combo = $1',
            [comboId]
        );
        res.json(resp.rows);
    } catch (err) { console.error(err.message) }
});

app.get('/combo/:comboId', async(req, res) => {
    try {
        const {comboId} = req.params;
        const resp = await pool.query(
            'select * from combo where codigo = $1',
            [comboId]
        );
        res.json(resp.rows);
    } catch (err) { console.error(err.message) }
});

app.get('/combo/stock/:comboId', async(req, res) => {
    try {
        const {comboId} = req.params;
        const resp = await pool.query(
            'select min(p.stock) from productoxcombo pc, producto p where pc.producto = p.codigo and pc.combo = $1',
            [comboId]
        );
        res.json(resp.rows[0]);
    } catch (err) { console.error(err.message) }
});

app.get('/comprado/producto/:usuario/:prodId/:estado', async(req, res) => {
    try {
        const {usuario, prodId, estado} = req.params;
        const resp = await pool.query(
            'select count(lp.producto) > 0 as comprado from compra co, lineaProductos lp WHERE $1=co.usuario and co.carrito=lp.carrito and lp.producto = $2 and co.estado=$3',
            [usuario, prodId, estado]
        );
        res.json(resp.rows[0]);
    } catch (err) { console.error(err.message) }
});

app.get('/compra/estado/:cartId', async(req, res) => {
    try {
        const { cartId } = req.params;
        const resp = await pool.query(
            'select estado from compra where carrito = $1',
            [ cartId ]
        );
        res.json(resp.rows[0]);
    } catch (err) { console.error(err.message) }
});

app.get('/calificacion/:prodId/:usuario', async(req, res) => {
    try {
        const { prodId, usuario } = req.params;
        const resp = await pool.query(
            'select $1 in (select producto from calificacion where usuario = $2) as existe',
            [ prodId, usuario ]
        );
        res.json(resp.rows[0]);
    } catch (err) { console.error(err.message) }
});

app.get('/search/:text', async(req, res) => {
    try {
        const { text } = req.params;
        const toSearch = ('%'+text+'%')
        const resp = await pool.query(
            'select * from producto where nombre ilike $1 or descripcion ilike $1',
            [toSearch]
        );
        res.json(resp.rows);
    } catch (err) { console.error(err.message) }
})

app.get('/user/exists/:email', async(req, res) => {
    try {
        const { email } = req.params;
        const resp = await pool.query(
            'select count(email) = 1 as exists from usuario where email = $1 and not suspendido',
            [email]
        );
        res.json(resp.rows[0]);
    } catch (err) { console.error(err.message) }
})

app.get('/proveedores', async(req, res) => {
    try {
        const resp = await pool.query(
            'select * from proveedor order by nombre');
        res.json(resp.rows);
    } catch (err) { console.error(err.message) }
});

app.get('/ventas', async(req, res) => {
    try {
        const resp = await pool.query(
            'select * from compra order by fecha desc');
        res.json(resp.rows);
    } catch (err) { console.error(err.message) }
});

app.get('/venta/:cartId', async(req, res) => {
    try {
        const {cartId} = req.params;
        const resp = await pool.query(
            'select l.codigo, l.cantidadproducto, l.carrito, p.nombre, p.codigo as prodId, c.total, c.fecha, c.estado, false as iscombo from compra c, linea l, producto p where c.carrito = l.carrito and p.codigo = l.producto and c.carrito = $1 union select l.codigo, l.cantidadproducto, l.carrito, co.nombre, co.codigo as prodId, c.total, c.fecha, c.estado, true as iscombo from linea l, compra c, combo co where co.codigo = l.combo and l.carrito = c.carrito and l.carrito = $1',
            [cartId]
        );
        res.json(resp.rows);
    } catch (err) { console.error(err.message) }
})

app.get('/proveedores/activos', async(req, res) => {
    try {
        const resp = await pool.query(
            'select distinct pr.* from producto p, proveedor pr where p.proveedor = pr.cuit'
        );
        res.json(resp.rows);
    } catch (err) { console.error(err.message) }
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
    } catch (err) { console.error(err.message) }
})

app.put('/usuario/carritoActual/:email/:cartId', async(req, res) => {
    try {
        const { email, cartId } = req.params;
        const updatedUser = await pool.query(
            'update usuario set carritoActual = $1 where email = $2',
            [cartId, email]     
        )
        res.json(updatedUser);
    } catch (err) { console.error(err.message) }
})

app.put('/usuario/actualizar/:nombre/:apellido/:ciudad/:direccion/:telefono/:email', async(req, res) => {
    try {
        const { nombre, apellido, ciudad, direccion, telefono, email } = req.params;
        const upd = await pool.query(
            'update usuario set nombre = $1, apellido = $2, ciudad = $3, direccion = $4, telefono = $5 where email = $6',
            [nombre, apellido, ciudad, direccion, telefono, email]     
        )
        res.json(upd);
    } catch (err) { console.error(err.message) }
})

app.put('/compra/actualizar/:cartId/:estado', async(req, res) => {
    try {
        const { estado, cartId } = req.params;
        const resp = await pool.query(
            'update compra set estado = $1 where carrito = $2',
            [ estado, cartId ]     
        )
        res.json(resp);
    } catch (err) { console.error(err.message) }
})

app.put('/usuario/password/:password/:email', async(req, res) => {
    try {
        const { password, email } = req.params;
        const resp = await pool.query(
            'update usuario set contrasenia = $1 where email = $2',
            [ password, email ]     
        )
        res.json(resp);
    } catch (err) { console.error(err.message) }
})

app.put('/producto/:name/:stock/:price/:stockmin/:descrip/:supplier/:type/:disc/:code', async(req, res) => {
    try {
        const { name, stock, price, stockmin, descrip, supplier, type, disc, code } = req.params;
        const resp = await pool.query(
            'update producto set nombre = $1, stock = $2, precio = $3, stockmin = $4, descripcion = $5, proveedor = $6, tipo = $7, porcdescuento = $8 where codigo = $9',
            [ name, stock, price, stockmin, descrip, supplier, type, disc, code ]
        )
        res.json(resp);
    } catch (err) { console.error(err.message) }
})

app.put('/combo/:code/:name/:description/:price', async(req, res) => {
    try {
        const { code, name, description, price } = req.params;
        const resp = await pool.query(
            'update combo set nombre = $2, descripcion = $3, precio = $4 where codigo = $1',
            [ code, name, description, price ]
        )
        res.json(resp);
    } catch (err) { console.error(err.message) }
})

app.put('/proveedor/:cuit/:name/:email/:tel/:city/:dir', async(req, res) => {
    try {
        const { cuit, name, email, tel, city, dir } = req.params;
        const resp = await pool.query(
            'update proveedor set nombre = $2, email = $3, telefono = $4, ciudad = $5, direccion = $6 where cuit = $1',
            [ cuit, name, email, tel, city, dir ]
        )
        res.json(resp);
    } catch (err) { console.error(err.message) }
})

app.put('/usuario/suspendido/:email/:estado', async(req, res) => {
    try {
        const { email, estado } = req.params;
        const resp = await pool.query(
            'update usuario set suspendido = $2 where email = $1',
            [ email, estado ]
        )
        res.json(resp);
    } catch (err) { console.error(err.message) }
})

app.put('/admin/rol/:email/:rol', async(req, res) => {
    try {
        const { email, rol } = req.params;
        const resp = await pool.query(
            'update usuario set rol = $2 where email = $1',
            [ email, rol ]
        )
        res.json(resp);
    } catch (err) { console.error(err.message) }
})



//POSTS
app.post('/carrito/crearCarrito', async(req, res) => {
    try {
        const newCarrito = await pool.query(
            'insert into carrito default values returning codigo'     
        )
        res.json(newCarrito.rows);
    } catch (error) { console.error(err.message) }
})

app.post('/usuario/carritoActual/:cartId', async(req, res) => {
    try {
        const { cartId } = req.params;
        const newCarrito = await pool.query(
            'insert into carrito default values'     
        )
        res.json(newCarrito);
    } catch (error) { console.error(err.message) }
})

app.post('/carrito/agregarProducto/:cant/:opc/:prodId/:cartId', async(req, res) => {
    try {
        const { cant, opc, prodId, cartId } = req.params;
        let prodEnCarrito;
        if (opc === '0'){
            prodEnCarrito = await pool.query(
                'insert into linea(cantidadproducto, producto, carrito) values($1, $2, $3)',
                [cant, prodId, cartId]
            )
        } else {
            prodEnCarrito = await pool.query(
                'insert into linea(cantidadproducto, combo, carrito) values($1, $2, $3)',
                [cant, prodId, cartId]
            )
        }
        res.json(prodEnCarrito);
    } catch (error) { console.error(err.message) }
})

app.post('/comprar/:total/:fecha/:hora/:numerotarjeta/:tipotarjeta/:carrito/:usuario', async(req, res) => {
    try {
        const { total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario } = req.params;
        const newCompra = await pool.query(
            'insert into compra(total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario) values($1, $2, $3, $4, $5, $6, $7)',
            [total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario]     
        )
        res.json(newCompra);
    } catch (error) { console.error(err.message) }
})

app.post('/producto/calificar/:calificacion/:fecha/:hora/:usuario/:producto', async(req, res) => {
    try {
        const { calificacion, fecha, hora, usuario, producto } = req.params;
        const resp = await pool.query(
            'insert into calificacion(calificacion, fecha, hora, usuario, producto) values($1, $2, $3, $4, $5);',
            [calificacion, fecha, hora, usuario, producto]     
        )
        res.json(resp);
    } catch (err) { console.error(err.message) }
})

app.post('/crear/usuario/:email/:username/:password/:name/:lastname/:address/:city/:tel', async(req, res) => {
    try {
        const { email, username, password, name, lastname, address, city, tel } = req.params;
        const resp = await pool.query(
            'insert into usuario values($1, $2, $3, 4, $4, $5, $6, $7, $8)',
            [email, username, password, name, lastname, address, city, tel]     
        )
        res.json(resp);
    } catch (err) { console.error(err.message) }
})

app.post('/nuevo/producto/:name/:stock/:stockmin/:price/:disc/:descrip/:supplier/:type/:img', async(req, res) => {
    try {
        const { name, stock, stockmin, price, disc, descrip, supplier, type, img } = req.params;
        const url = img.split('|').join('/')
        const resp = await pool.query(
            'insert into producto(nombre, stock, stockmin, precio, porcdescuento, descripcion, proveedor, tipo, imagen) values($1, $2, $3, $4, $5, $6, $7, $8, $9)',
            [name, stock, stockmin, price, disc, descrip, supplier, type, url]     
        )
        res.json(resp);
    } catch (err) { console.error(err.message) }
})

app.post('/nuevo/combo/:name/:price/:descrip', async(req, res) => {
    try {
        const { name, price, descrip } = req.params;
        const today = new Date(),
            inicio = today.getFullYear() + '-' + (today.getMonth() + 1) + '-' + today.getDate(),
            final = (today.getFullYear() + 1) + '-' + (today.getMonth() + 1) + '-' + today.getDate()
        const resp = await pool.query(
            'insert into combo(nombre, precio, fechainicio, fechafinal, descripcion) values($1, $2, $3, $4, $5) returning codigo',
            [name, price, inicio, final, descrip]     
        )
        res.json(resp.rows[0]);
    } catch (err) { console.error(err.message) }
})

app.post('/nuevo/comboxproducto/:productCode/:comboCode', async(req, res) => {
    try {
        const { productCode, comboCode } = req.params;
        const resp = await pool.query(
            'insert into productoxcombo values($1, $2)',
            [productCode, comboCode]     
        )
        res.json(resp);
    } catch (err) { console.error(err.message) }
})

app.post('/nuevo/proveedor/:cuit/:name/:email/:tel/:city/:dir', async(req, res) => {
    try {
        const { cuit, name, email, tel, city, dir } = req.params;
        const resp = await pool.query(
            'insert into proveedor values($1, $2, $6, $5, $3, $4)',
            [cuit, name, email, tel, city, dir]     
        )
        res.json(resp);
    } catch (err) { console.error(err.message) }
})


//delete
app.delete('/usuario/:email', async (req, res) => {
    try {
        const { email } = req.params;
        const deleteUser = await pool.query(
            'delete from usuario where email = $1',
            [email]
        );
        res.json(deleteUser.rows)
    } catch (err) { console.error(err.message) }
})

app.delete('/carrito/vaciar/:cartId', async (req, res) => {
    try {
        const { cartId } = req.params;
        const vaciado = await pool.query(
            'delete from linea where carrito = $1',
            [cartId]
        );
        res.json(vaciado.rows)
    } catch (err) { console.error(err.message) }
})

app.delete('/carrito/producto/:lineCod', async (req, res) => {
    try {
        const { lineCod } = req.params;
        const deleteCart = await pool.query(
            'delete from linea where codigo = $1',
            [lineCod]
        );
        res.json(deleteCart.rows)
    } catch (err) { console.error(err.message) }
})

app.delete('/usuario/carritoActual/:email', async (req, res) => {
    try {
        const { email } = req.params;
        const deleteUser = await pool.query(
            'delete from carrito where codigo = (select carritoactual from usuario where email = $1)',
            [email]
        );
        res.json(deleteUser.rows)
    } catch (err) { console.error(err.message) }
})

app.delete('/combo/:codigo', async (req, res) => {
    try {
        const { codigo } = req.params;
        const deleteUser = await pool.query(
            'delete from combo where codigo = $1',
            [codigo]
        );
        res.json(deleteUser.rows)
    } catch (err) { console.error(err.message) }
})

app.delete('/productoxcombo/:producto/:combo', async (req, res) => {
    try {
        const { producto, combo } = req.params;
        const deleteUser = await pool.query(
            'delete from productoxcombo where producto = $1 and combo = $2',
            [producto, combo]
        );
        res.json(deleteUser.rows)
    } catch (err) { console.error(err.message) }
})

app.delete('/proveedor/:cuit', async (req, res) => {
    try {
        const { cuit } = req.params;
        const resp = await pool.query(
            'delete from proveedor where cuit = $1',
            [cuit]
        );
        res.json(resp)
    } catch (err) { console.error(err.message) }
})

app.delete('/compra/:code', async (req, res) => {
    try {
        const { code } = req.params;
        const resp = await pool.query(
            'delete from compra where codigo = $1',
            [code]
        );
        res.json(resp)
    } catch (err) { console.error(err.message) }
})




app.listen(5000, () => {
    console.log('Server has started on port 5000');
})


