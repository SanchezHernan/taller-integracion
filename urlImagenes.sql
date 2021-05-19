--Creamos las tablas de la BBDD

create table rol(
  	codigo SERIAL,
	nombre varchar(25) NOT NULL unique,
	constraint nombre_rol check (nombre in
	('ADMINISTRADOR GENERAL','ADMINISTRADOR VENTAS','ADMINISTRADOR STOCK','CLIENTE')),
	constraint "rol_pkey" Primary Key (codigo)
);

create table usuario(
	email varchar(255) NOT NULL unique,
	nombreuser varchar(30) NOT NULL unique,
	contrasenia varchar(30) NOT NULL,
	rol integer NOT NULL,
	nombre varchar(50) NOT NULL,
	apellido varchar(50) NOT NULL,
	direccion varchar(70),
	ciudad varchar(70),
	telefono varchar(15),
	constraint "usuario_pkey" Primary Key (email),
	foreign key (rol) references rol
);

create table tipo(
  	codigo SERIAL,
	nombre varchar(20) NOT NULL unique,
	constraint nombre_tipo check (nombre in
	('YERBA','MATE','BOMBILLA','TERMO','PORTATERMO','OTRO')),
	constraint "tipo_pkey" Primary Key (codigo)
);

create table proveedor(
	cuit varchar(11) NOT NULL unique,
	nombre varchar(50) NOT NULL,
	direccion varchar(70) NOT NULL,
	ciudad varchar(70) NOT NULL,
	email varchar(255) NOT NULL unique,
	telefono varchar(15),
	constraint "proveedor_pkey" Primary Key (cuit)
);

create table producto(
	codigo SERIAL,
	nombre varchar(70) NOT NULL,
	stock integer NOT NULL check (stock>0),
	precio float NOT NULL check (precio>0),
	stockmin integer NOT NULL check (stockmin>0) default 10,
	descripcion varchar(255) NOT NULL,
	calificacion integer NOT NULL check(calificacion in (0,1,2,3,4,5)) default 0,
	proveedor varchar(11) NOT NULL,
	tipo integer NOT NULL,
	constraint "producto_pkey" Primary Key (codigo),	
	foreign key (proveedor) references proveedor,
	foreign key (tipo) references tipo
);

create table calificacion(
	calificacion integer NOT NULL check (calificacion in (1,2,3,4,5)),
	fecha date NOT NULL,
	hora time NOT NULL,
	usuario varchar(255) NOT NULL,
	producto integer NOT NULL,
	constraint "calificacion_pkey" Primary Key (usuario,producto),
	foreign key (usuario) references usuario,
	foreign key (producto) references producto
);

create table comentario(
	codigo SERIAL,
	fecha date NOT NULL,
	hora time NOT NULL,
	contenido varchar(255) NOT NULL,
	usuario varchar(255) NOT NULL,
	producto integer NOT NULL,
	constraint "comentario_pkey" Primary Key (codigo),
	foreign key (usuario) references usuario,
	foreign key (producto) references producto
);

create table combo(
	codigo SERIAL,
	nombre varchar(70) NOT NULL,
	precio float NOT NULL check (precio>0),
	fechainicio date NOT NULL,
	fechafinal date NOT NULL check (fechainicio<=fechafinal),
	descripcion varchar(255) NOT NULL,
	constraint "combo_pkey" Primary Key (codigo)
);

create table productoxcombo(
	producto integer NOT NULL,
	combo integer NOT NULL,
	constraint "productoxcombo_pkey" Primary Key (producto,combo),	
	foreign key (producto) references producto,	
	foreign key (combo) references combo
);

create table carrito(
	codigo SERIAL,
	constraint "carrito_pkey" Primary Key (codigo)
);

create table linea(
	codigo SERIAL,
	cantidadproducto integer NOT NULL check(cantidadproducto>0),
	totalproducto float NOT NULL check(totalproducto>0),
	producto integer,
	combo integer,
	carrito integer NOT NULL,
	constraint "linea_pkey" Primary Key (codigo),	
	foreign key (carrito) references carrito,
	foreign key (producto) references producto,	
	foreign key (combo) references combo
);

create table compra(
	codigo SERIAL,
	total float NOT NULL check(total>0),
	fecha date NOT NULL,
	hora time NOT NULL,
	numerotarjeta varchar(20) NOT NULL,
	tipotarjeta varchar(30) NOT NULL,
	carrito integer NOT NULL unique,
	usuario varchar(255) NOT NULL,
	estado varchar(30) NOT NULL default 'ESPERA',
	constraint "compra_pkey" Primary Key (codigo),	
	constraint nombre_estado check (estado in
	('CANCELADA','FINALIZADA','ESPERA')),
	foreign key (carrito) references carrito,
	foreign key (usuario) references usuario
);


-- Vistas --
CREATE VIEW lineaProductos AS SELECT * FROM linea WHERE producto is not null;
CREATE VIEW proveedorMasProductos AS SELECT p.proveedor, COUNT(p.proveedor) AS productos_provistos
	FROM producto p GROUP BY p.proveedor ORDER BY productos_provistos DESC LIMIT 1;
CREATE VIEW productosMuchosCombos AS SELECT distinct pxc1.producto FROM productoxcombo pxc1, productoxcombo pxc2
	WHERE pxc1.producto=pxc2.producto and pxc1.combo!=pxc2.combo;
CREATE VIEW debajoStockMin AS SELECT p.codigo, p.nombre, p.tipo, p.proveedor FROM producto p where p.stock < p.stockmin;


-- Funciones --
-- 1. Usuario que realizo más compras ente dos fechas --
CREATE OR REPLACE FUNCTION UsuarioMayorCantidadCompras(date, date) RETURNS TABLE (usuario varchar(255), cantidad_compras bigint) AS
$BODY$
DECLARE
BEGIN
	return query (SELECT c.usuario, count(c.usuario) AS mayor_comprador FROM compra c WHERE c.fecha BETWEEN $1 and $2
			 GROUP BY c.usuario ORDER BY mayor_comprador DESC LIMIT 1);
end
$BODY$
LANGUAGE 'plpgsql';

-- 2. Dado un combo, ver cuantos se vendieron en el periodo que estuvo disponible -- 
CREATE OR REPLACE FUNCTION combosVendidosPeriodo(varchar(70)) RETURNS TABLE (codigo integer, cantidad_vendidos bigint) AS
$BODY$
DECLARE
BEGIN
	return query (SELECT c.codigo, count(lc.cantidadproducto) AS mayor_ventas 
	FROM combo c, lineaCombos lc, carrito ca, compra co 
	WHERE c.nombre=$1 and lc.combo=c.codigo and lc.carrito=ca.codigo and co.carrito=ca.codigo and co.fecha BETWEEN c.fechainicio and c.fechafinal
	GROUP BY c.codigo ORDER BY mayor_ventas DESC LIMIT 1);
end
$BODY$
LANGUAGE 'plpgsql';

-- 3. Cantidad de productos de un determinado tipo --
CREATE OR REPLACE FUNCTION cantidadMismoTipo(tipoo int) RETURNS TABLE (tipo int, cantidad bigint) AS
$BODY$ 
DECLARE
BEGIN
	return query(SELECT p.tipo, count(p.tipo) FROM producto p
	group by p.tipo having p.tipo = $1);
end
$BODY$
LANGUAGE 'plpgsql';

-- 6. Producto más solicitado o vendido durante cierto periodo --
CREATE OR REPLACE FUNCTION productoMasVendidoPeriodo(date, date) RETURNS TABLE (producto integer, cantidad_vendidos bigint) AS
$BODY$
DECLARE
BEGIN
	return query (SELECT lp1.producto, SUM(lp1.cantidadproducto) AS unidades_vendidas
	FROM lineaProductos lp1, carrito ca, compra co 
	WHERE lp1.carrito=ca.codigo and ca.codigo=co.carrito and co.fecha between $1 and $2
	GROUP BY lp1.producto ORDER BY unidades_vendidas DESC LIMIT 1);
end
$BODY$
LANGUAGE 'plpgsql';

-- Contar si la cantidad de una linea es menor que el stock de los productos de un combo  --
CREATE OR REPLACE FUNCTION cantidadLineaProductosCombo(integer, integer) RETURNS boolean AS
$BODY$
DECLARE
	contadortotal integer;
	contadorparcial integer;
BEGIN
	contadortotal:= (select count(pc.combo) from productoxcombo pc where $2=pc.combo);
	contadorparcial:= (select count(pc.combo) from productoxcombo pc, producto p
	where $2=pc.combo and pc.producto=p.codigo and $1<=p.stock);
	if(contadortotal=contadorparcial)then
		return true;
	else
		return false;
	end if;
end; $BODY$ LANGUAGE 'plpgsql';


-- Triggers
-- 1. Controlar que cuando se carga una línea solo puede haber un producto o combo, no ambos --
CREATE OR REPLACE FUNCTION controlLinea() RETURNS TRIGGER AS $funcemp$
DECLARE
BEGIN
	IF ((NEW.producto is null) and (NEW.combo is not null)) THEN
		RETURN NEW;
	ELSIF ((NEW.combo is null) and (NEW.producto is not null)) THEN
		RETURN NEW;
	ELSE
		RAISE EXCEPTION 'Solo se puede tener un producto o combo por linea';
	END IF;
END; $funcemp$ LANGUAGE plpgsql;

CREATE TRIGGER triggerControlLinea BEFORE INSERT OR UPDATE ON linea
FOR EACH ROW EXECUTE PROCEDURE controlLinea();

-- 2. Controlar que para calificar un producto, se debe haber realizado una compra del mismo previamente --
CREATE OR REPLACE FUNCTION controlCalificacionCompra() RETURNS TRIGGER AS $funcemp$
DECLARE
productoCompra bigint;
BEGIN
	productoCompra:= (select count(lp.producto) from compra co, carrito ca, lineaProductos lp
	WHERE NEW.usuario=co.usuario and ca.codigo=co.carrito and ca.codigo=lp.carrito and lp.producto=NEW.producto and co.estado='FINALIZADA');
	IF (productoCompra!=0) THEN
		RETURN NEW;
	ELSE
		RAISE EXCEPTION 'Debe realizar alguna compra del producto para poder calificarlo';
	END IF;
END; $funcemp$ LANGUAGE plpgsql;

CREATE TRIGGER triggerControlCalificacionCompra BEFORE INSERT OR UPDATE ON calificacion
FOR EACH ROW EXECUTE PROCEDURE controlCalificacionCompra();

-- 3. Cuando se realiza una calificación, actualizar la calificación actual del producto --
create or replace function actualizarCalificacion() RETURNS TRIGGER AS $funcemp$
declare
	promedio float;
	calif integer;
BEGIN
	promedio:= (select avg(calificacion) from calificacion where producto=NEW.producto);
	calif:= CAST ((select ROUND(promedio)) AS integer);
	update producto set calificacion=calif where codigo=NEW.producto;
	return new;
END;$funcemp$ LANGUAGE plpgsql;

create trigger triggerActualizarCalificacion after insert or update on calificacion
for each row execute procedure actualizarCalificacion();

-- 4. Verificacion de que solamente el estado ESPERA de la compra pase a otro estado, y control de que en la actualizacion
-- no se cambien otros datos de la compra.
create or replace function cambiarEstadoCompra() RETURNS TRIGGER AS $funcemp$
declare
BEGIN
	IF (OLD.estado='CANCELADA') THEN
		RAISE EXCEPTION 'No se puede cambiar el estado de una compra cancelada';
	ELSIF (OLD.estado='FINALIZADA') THEN
		RAISE EXCEPTION 'No se puede cambiar el estado de una compra finalizada';
	ELSIF (OLD.estado='ESPERA' and OLD.total=NEW.total and OLD.fecha=NEW.fecha and OLD.hora=NEW.hora and 
		  OLD.numerotarjeta=NEW.numerotarjeta and OLD.tipotarjeta=NEW.tipotarjeta and OLD.carrito=NEW.carrito and
		  OLD.usuario=NEW.usuario) THEN
		RETURN NEW;
	ELSE
		RAISE EXCEPTION 'No se pueden cambiar los valores de la compra, solo su estado';
	END IF;
END;$funcemp$ LANGUAGE plpgsql;

create trigger triggerControlCompra BEFORE update on compra
for each row execute procedure cambiarEstadoCompra();

-- 5. Verificacion de que la cantidad de productos a comprar en una linea, sea menor o igual que el stock disponible
create or replace function cantidadProductosLinea() RETURNS TRIGGER AS $funcemp$
declare  
	cantidad integer;
	valor boolean;
BEGIN
	IF ((NEW.combo is null) and (NEW.producto is not null)) THEN
		cantidad:= (select p.stock from producto p where p.codigo=NEW.producto);
		IF(cantidad<NEW.cantidadproducto) THEN
			RAISE EXCEPTION 'La cantidad de productos a comprar excede el stock';
		ELSE
			return new;
		END IF;
	ELSIF ((NEW.producto is null) and (NEW.combo is not null)) THEN
		valor:= cantidadLineaProductosCombo(NEW.cantidadproducto, NEW.combo);
		IF(valor)THEN
			return new;
		ELSE
			RAISE EXCEPTION 'La cantidad de productos a comprar excede el stock';
		END IF;
	ELSE
		RAISE EXCEPTION 'Solo se puede tener un producto o combo por linea';
	END IF;
END;$funcemp$ LANGUAGE plpgsql;

create trigger cantidadProductosLinea BEFORE insert or update on linea
for each row execute procedure cantidadProductosLinea();


-- Creacion de Usuarios --
CREATE USER AdministradorStock PASSWORD '12345';
CREATE USER AdministradorVentas PASSWORD '12345';

-- Otorgamos los Roles a los Usuarios -- 
GRANT ALL ON combo TO AdministradorVentas;
GRANT select ON producto, compra, usuario TO AdministradorVentas;
GRANT ALL on producto, proveedor TO AdministradorStock;

-- Otorgamos permisos a los atributos del tipo SERIAL de las tablas -- 
GRANT USAGE, SELECT ON SEQUENCE combo_codigo_seq, producto_codigo_seq, compra_codigo_seq TO AdministradorVentas;
GRANT USAGE, SELECT ON SEQUENCE producto_codigo_seq TO AdministradorStock;


-- INSERTS --

-- Proveedores --
insert into proveedor values('3011111111', 'Proveedor A', '3 de Febrero 111', 'Concepcion del Uruguay', 'proveedora@xmail.com', '11111111');
insert into proveedor values('3022222222', 'Proveedor B', 'Tibiletti 222', 'Concepcion del Uruguay', 'proveedorb@xmail.com', '22222222');
insert into proveedor values('3033333333', 'Proveedor C', 'Ingeniero Henry 313', 'Gualeguaychu', 'proveedorc@xmail.com', '33333333');
insert into proveedor values('3044444444', 'Proveedor D', 'Mariano Moreno 414', 'Colon', 'proveedord@xmail.com', '44444444');
insert into proveedor values('3055555555', 'Proveedor E', 'Justo Jose de Urquiza 441', 'Concepcion del Uruguay', 'proveedore@xmail.com', '55555555');
insert into proveedor values('3066666666', 'Proveedor F', 'Ferrari 564', 'Colon', 'proveedorf@xmail.com', '666666666');
insert into proveedor values('3077777777', 'Proveedor G', 'Sarmiento 112', 'San jose', 'proveedorg@xmail.com', '77777777');
insert into proveedor values('3088888888', 'Proveedor H', 'Mariano Moreno 512', 'Concepcion del Uruguay', 'proveedorh@xmail.com', '88888888');
insert into proveedor values('3099999999', 'Proveedor I', '25 de Mayo 167', 'Gualeguaychu', 'proveedori@xmail.com', '99999999');
insert into proveedor values('3000000000', 'Proveedor J', 'Almafuerte 128', 'Concepcion del Uruguay', 'proveedorj@xmail.com', '00000000');

-- Tipos --
insert into tipo values(1, 'MATE');
insert into tipo values(2, 'TERMO');
insert into tipo values(3, 'BOMBILLA');
insert into tipo values(4, 'PORTATERMO');
insert into tipo values(5, 'YERBA');
insert into tipo values(6, 'OTRO');

-- Productos --
insert into producto(nombre, stock, precio, descripcion, proveedor, tipo)
	values('Mate Uruguayo Calabaza', 500, 700, 'Mate Uruguayo hecho de las mejores calabazas', '3011111111', 1);
insert into producto(nombre, stock, precio, descripcion, proveedor, tipo)
	values('Mate Uruguayo Cuero', 500, 900, 'Mate Uruguayo de cuero; colores: negro y marron', '3011111111', 1);
insert into producto(nombre, stock, precio, descripcion, proveedor, tipo)
	values('Mate Madera', 500, 400, 'Mate hecho de madera de calden; colores: rosa, azul, amarillo, negro', '3022222222', 1);
insert into producto(nombre, stock, precio, descripcion, proveedor, tipo)
	values('Mate Uruguayo Camionero Premium', 500, 1200, 'Mates realizados con calabazas y cuero finamente seleccionados', '3033333333', 1);
insert into producto(nombre, stock, precio, descripcion, proveedor, tipo)
	values('Bombilla Pico Loro Tambor', 500, 295, 'Bombilla Uruguaya Pico de Loro, de acero inoxidable, tipo tambor', '3044444444', 3);
insert into producto(nombre, stock, precio, descripcion, proveedor, tipo)
	values('Bombilla Metalica', 500, 199, 'Bombillas metalicas de varios colores de tipo resorte', '3044444444', 3);
insert into producto(nombre, stock, precio, descripcion, proveedor, tipo)
	values('Yerba Marolio', 494, 100, 'Yerba Mate Marolio, Marolio le da sabor a tu vida', '3055555555', 5);
insert into producto(nombre, stock, precio, descripcion, proveedor, tipo)
	values('Bolso para Mate Tahg', 500, 750, 'Bolso con cierre, tipo tahg, con bolsillo frontal', '3066666666', 4);
insert into producto(nombre, stock, precio, descripcion, proveedor, tipo)
	values('Bolso para Mate Gamuza', 5, 859, 'Bolso porta termo negro de poliester con gamuza', '3066666666', 4);
insert into producto(nombre, stock, precio, descripcion, proveedor, tipo)
	values('Automate Forrado', 500, 400, 'Mate Listo Automate Forrado de Metal 500cc', '3088888888', 6);
insert into producto(nombre, stock, precio, descripcion, proveedor, tipo)
	values('Termo Waterdog', 500, 2100, 'Termo Waterdog de acero inoxidable, de 1 litro, tipo bala', '3099999999', 2);
insert into producto(nombre, stock, precio, descripcion, proveedor, tipo)
	values('Termo Aluminio', 500, 500, 'Termo Aluminio Doble Capa Varios Colores 1 Litro', '3099999999', 2);
insert into producto(nombre,stock,precio,descripcion,proveedor,tipo)
	values('Termo Stanley', 500, 3500, 'El mismo termo pero careta', '3099999999',2);

-- Roles --
insert into rol(nombre) values('ADMINISTRADOR GENERAL');
insert into rol(nombre) values('ADMINISTRADOR VENTAS');
insert into rol(nombre) values('ADMINISTRADOR STOCK');
insert into rol(nombre) values('CLIENTE');

-- Usuarios --
insert into usuario values(
	'exe.gye@gmail.com', 'Exegye', 'exe123', 1, 'Exequiel', 'Gonzalez', '25 de Agosto 231', 'Concepcion del Uruguay', '3442647543');
insert into usuario values(
	'juancurtoni@gmail.com', 'Pipa Benedeto', 'juan123', 2, 'Juan', 'Curtoni', 'San Martin 362', 'Concepcion del Uruguay', '3445536635');
insert into usuario values(
	'sanchezhernan@gmail.com', 'Hornit0', 'hernan123', 3, 'Hernan', 'Sanchez', 'J. Peron 465', 'Concepcion del Uruguay', '3445431625');
insert into usuario values(
	'lazaro@gmail.com', 'Lazaro', 'laza123', 4, 'Lazaro', 'Rodriguez', '9 de Julio 3441', 'La Plata', '2114526721');
insert into usuario values(
	'kevinchen@gmail.com', 'Kevin', 'kevin123', 4, 'Kevin', 'Chen', '12 de Octubre 552', 'Concepcion del Uruguay', '3442647543');
insert into usuario values(
	'verocafrete@gmail.com', 'Verost', 'vero123', 4, 'Veronica', 'Frete', 'J. J. Urquiza 41', 'Posadas', '3764256216');
insert into usuario values(
	'danieldorado@gmail.com', 'Puerco', 'dani123', 4, 'Daniel', 'Dorado', 'Corrientes 467', 'Cordoba', '3511232597');
insert into usuario values(
	'luisreyes@gmail.com', 'Luisito', 'luis123', 4, 'Luis', 'Reyes', '25 de Agosto 231', 'Mar del Plata', '2236548962');
insert into usuario values(
	'tamaralozano@gmail.com', 'Tami22', 'tami123', 4, 'Tamara', 'Lozano', 'Colon 668', 'Naschel', '2656332584');
insert into usuario values(
	'carlospalacios@gmail.com', 'CarlosP', 'carlos123', 4, 'Carlos', 'Palacios', '3 de Febrero 989', 'General Pico', '2302424562');

-- Combos --
insert into combo(nombre, precio, fechainicio, fechafinal, descripcion) values(
	'Combo de Mate Calabaza y bombilla Pico Loro', 995, '2009-11-13', '2010-11-13', 'Mate Uruguayo hecho de las mejores calabazas con Bombilla Uruguaya Pico de Loro, de acero inoxidable, tipo tambor');
insert into combo(nombre, precio, fechainicio, fechafinal, descripcion) values(
	'Combo de Mate Premium y bombilla Pico Loro', 1495, '2009-11-13', '2010-11-13', 'Mate realizado con calabazas y cuero finamente seleccionados con Bombilla Uruguaya Pico de Loro, de acero inoxidable, tipo tambor');
insert into combo(nombre, precio, fechainicio, fechafinal, descripcion) values(
	'Combo de Mate, Bombilla, Termo Aluminio y Bolso para Mate', 2149, '2009-11-13', '2010-11-13', 'Mate Uruguayo hecho de las mejores calabazas con Bombilla Matelica tipo resorte, Termo Aluminio Doble Capa y Bolso con cierre, tipo tahg con cierre frontal');
insert into combo(nombre, precio, fechainicio, fechafinal, descripcion) values(
	'Combo de Mate Uruguayo Cuero y Mate Uruguayo Calabaza', 1600, '2011-10-15', '2013-12-07', 'Promocion de dos Mates Uruguayos -Calabaza y Cuero-');
insert into combo(nombre, precio, fechainicio, fechafinal, descripcion) values(
	'Combo Termo Aluminio y Automate Forrado', 3900, '2010-10-12', '2015-05-01', 'Promocion de termo Aluminio mas Automate-');
insert into combo(nombre, precio, fechainicio, fechafinal, descripcion) values(
	'Combo Bolso para Mate Tahg y Yerba Marolio', 850, '2016-04-24', '2018-10-25', 'Promocion de bolso Mate Tahg y Yerba Marolio-');
insert into combo(nombre, precio, fechainicio, fechafinal, descripcion) values(
	'Combo Mate Uruguayo Calabaza y Yerba Marolio', 800, '2005-02-15', '2010-05-14', 'Promocion de mate Uruguayo Calabaza y Yerba Marolio-');
insert into combo(nombre, precio, fechainicio, fechafinal, descripcion) values(
	'Combo Mate Uruguayo Calabaza y Termo Stanley', 4200, '2017-09-20', '2018-01-12', 'Promocion de mate Uruguayo Calabaza y Termo Stanley-');
insert into combo(nombre, precio, fechainicio, fechafinal, descripcion) values(
	'Combo Bombilla Metalica y Termo Aluminio', 699, '2013-08-14', '2019-12-12', 'Promocion de bombilla Melatica y Termo Aluminio-');
insert into combo(nombre, precio, fechainicio, fechafinal, descripcion) values(
	'Combo Mate Madera y Yerba Marolio', 500, '2015-11-24', '2017-04-06', 'Promocion de mate Madera y Yerba Marolio-');

-- ProductoxCombo --
insert into productoxcombo values(1, 1);
insert into productoxcombo values(5, 1);
insert into productoxcombo values(4, 2);
insert into productoxcombo values(5, 2);
insert into productoxcombo values(1, 3);
insert into productoxcombo values(6, 3);
insert into productoxcombo values(12, 3);
insert into productoxcombo values(8, 3);
insert into productoxcombo values(1, 4); 
insert into productoxcombo values(2, 4);
insert into productoxcombo values(10,5);
insert into productoxcombo values(12,5);
insert into productoxcombo values(7,6);
insert into productoxcombo values(8,6);
insert into productoxcombo values(7,7);
insert into productoxcombo values(1,7);
insert into productoxcombo values(1,8);
insert into productoxcombo values(13,8);
insert into productoxcombo values(12,9);
insert into productoxcombo values(6,9);
insert into productoxcombo values(7,10);
insert into productoxcombo values(3,10);

-- Comentario -- 
insert into comentario(fecha, hora, contenido, usuario, producto) values(
	'2019-10-14', '12:30:42', 'Producto de excelente calidad, muy recomendado', 'exe.gye@gmail.com',4);
insert into comentario(fecha, hora, contenido, usuario, producto) values(
	'2019-08-14', '22:10:00', 'El producto funciona correctamente', 'juancurtoni@gmail.com',2);
insert into comentario(fecha, hora, contenido, usuario, producto) values(
	'2017-02-03', '05:30:22', 'Producto de buena calidad a un precio barato', 'lazaro@gmail.com',8);
insert into comentario(fecha, hora, contenido, usuario, producto) values(
	'2018-12-01', '16:57:29', 'El producto no era lo que esperaba', 'luisreyes@gmail.com',11);
insert into comentario(fecha, hora, contenido, usuario, producto) values(
	'2019-09-11', '08:02:57', 'Buen producto', 'carlospalacios@gmail.com',6);
insert into comentario(fecha, hora, contenido, usuario, producto) values(
	'2018-04-24', '22:05:20', 'Excelente calidad', 'exe.gye@gmail.com',1);
insert into comentario(fecha, hora, contenido, usuario, producto) values(
	'2011-03-30', '01:40:40', 'Demasiado caro el producto', 'carlospalacios@gmail.com',6);
insert into comentario(fecha, hora, contenido, usuario, producto) values(
	'2014-02-01', '09:29:50', 'Producto super recomendado', 'verocafrete@gmail.com',7);
insert into comentario(fecha, hora, contenido, usuario, producto) values(
	'2016-10-25', '19:04:20', 'El producto llego a tiempo y sin problemas', 'sanchezhernan@gmail.com',11);
insert into comentario(fecha, hora, contenido, usuario, producto) values(
	'2015-01-30', '02:49:13', 'El producto llego una semana mas tarde', 'juancurtoni@gmail.com',5);

-- Carrito --
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));
insert into carrito values (nextval('carrito_codigo_seq'));

-- Linea -- 
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(6, 2400, 3, null, 2);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(3, 4485, null, 2, 1);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(20, 3980, 6, null, 3);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(1, 995, null, 1, 1);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(3, 995, 13, null, 1);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(5, 2000, 10, null, 4);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(10, 7000, 1, null, 3);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(30, 3000, 7, null, 5);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(4, 8596, null, 3, 6);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(15, 24000, null, 4, 6);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(18, 16200, 2, null, 3);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(4, 24000, 5, null, 6);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(15, 24000, null, 6, 7);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(8, 24000, 7, null, 7);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(15, 24000, null, 7, 8);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(1, 24000, 11, null, 8);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(15, 24000, null, 8, 9);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(8, 24000, 4, null, 9);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(15, 24000, null, 10, 10);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(4, 24000, 2, null, 10);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(7, 24000, 2, null, 11);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(3, 5500, 3, null, 12);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(6, 600, 7, null, 13);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(5, 600, 7, null, 14);
insert into linea(cantidadproducto, totalproducto, producto, combo, carrito) values(5, 600, 1, null, 14);

-- Compra --
-- Se insertan como finalizadas para poder realizar las calificaciones
insert into compra(total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario, estado) values(
	2400,'2019-04-24', '09:22:11', '3000000022222222', 'VISA', 2,'exe.gye@gmail.com', 'FINALIZADA');
insert into compra(total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario, estado) values(
	5480,'2010-06-12', '22:06:59', '9999888877776666', 'VISA', 1,'juancurtoni@gmail.com', 'FINALIZADA');
insert into compra(total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario, estado) values(
	27180,'2017-11-28', '15:42:10', '1111222233334444', 'MASTERCARD', 3,'lazaro@gmail.com', 'FINALIZADA');
insert into compra(total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario, estado) values(
	2000,'2014-04-03', '19:30:46', '2222333344449999', 'MASTERCARD', 4,'exe.gye@gmail.com', 'FINALIZADA');
insert into compra(total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario, estado) values(
	3000,'2018-06-22', '10:20:37', '4444555544445555', 'NARANJA', 5,'danieldorado@gmail.com', 'FINALIZADA');
insert into compra(total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario, estado) values(
	32596,'2019-02-24', '02:24:19', '9999222211110000', 'NARANJA', 6,'luisreyes@gmail.com', 'FINALIZADA');
insert into compra(total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario, estado) values(
	27180,'2015-10-31', '07:14:49', '8888444499992222', 'CABAL', 7,'juancurtoni@gmail.com', 'FINALIZADA');
insert into compra(total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario, estado) values(
	2000,'2016-08-14', '20:56:11', '1111333311112222', 'CABAL', 8,'juancurtoni@gmail.com', 'FINALIZADA');
insert into compra(total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario, estado) values(
	2000,'2019-01-02', '23:11:00', '5555333322221111', 'VISA', 9,'carlospalacios@gmail.com', 'FINALIZADA');
insert into compra(total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario, estado) values(
	2400,'2017-05-12', '13:48:15', '4444000044440000', 'MASTERCARD', 10,'kevinchen@gmail.com', 'FINALIZADA');
insert into compra(total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario, estado) values(
	2000,'2018-12-12', '11:42:15', '4422000011114444', 'MASTERCARD', 11,'exe.gye@gmail.com', 'FINALIZADA');
insert into compra(total, fecha, hora, numerotarjeta, tipotarjeta, carrito, usuario, estado) values(
	3290,'2014-05-22', '19:30:11', '4422999912214488', 'MASTERCARD', 12,'kevinchen@gmail.com', 'FINALIZADA');

-- Calificacion --
insert into calificacion(calificacion, fecha, hora, usuario, producto) values(
	5,'2019-01-06','20:10:33','exe.gye@gmail.com',3);
insert into calificacion(calificacion, fecha, hora, usuario, producto) values(
	4,'2019-02-14','10:22:13','carlospalacios@gmail.com',4);
insert into calificacion(calificacion, fecha, hora, usuario, producto) values(
	5,'2017-05-22','15:10:33','juancurtoni@gmail.com',13);
insert into calificacion(calificacion, fecha, hora, usuario, producto) values(
	4,'2015-02-13','14:13:12','lazaro@gmail.com',6);
insert into calificacion(calificacion, fecha, hora, usuario, producto) values(
	1,'2018-01-24','19:04:55','danieldorado@gmail.com',7);
insert into calificacion(calificacion, fecha, hora, usuario, producto) values(
	2,'2015-06-11','04:14:44','exe.gye@gmail.com',10);
insert into calificacion(calificacion, fecha, hora, usuario, producto) values(
	5,'2016-12-24','23:59:10','juancurtoni@gmail.com',7);
insert into calificacion(calificacion, fecha, hora, usuario, producto) values(
	5,'2016-12-24','23:59:10','juancurtoni@gmail.com',11);
insert into calificacion(calificacion, fecha, hora, usuario, producto) values(
	5,'2016-12-24','23:59:10','kevinchen@gmail.com',2);
insert into calificacion(calificacion, fecha, hora, usuario, producto) values(	5,'2018-11-21','21:02:16','exe.gye@gmail.com',2);




--ACTUALIZACIONES
--agregar columna {imagen} a la tabla {producto}
alter table producto add column imagen varchar;

update producto set imagen = 'https://http2.mlstatic.com/D_NQ_NP_612766-MLA32550451187_102019-W.jpg' where codigo = 1;
update producto set imagen = 'https://http2.mlstatic.com/D_NQ_NP_999071-MLA40612139964_012020-O.jpg' where codigo = 2;
update producto set imagen = 'https://images-na.ssl-images-amazon.com/images/I/71VhGrQfY%2BL._AC_SX225_.jpg' where codigo = 3;
update producto set imagen = 'https://d26lpennugtm8s.cloudfront.net/stores/001/062/836/products/01271-5bdd41497a5269086b15744570525788-1024-1024.jpg' where codigo = 4;
update producto set imagen = 'https://mla-s1-p.mlstatic.com/612245-MLA43126726472_082020-F.jpg' where codigo = 5;
update producto set imagen = 'https://http2.mlstatic.com/D_NQ_NP_638282-MLA43566813449_092020-V.jpg' where codigo = 6;
update producto set imagen = 'https://maxiconsumo.com/pub/media/catalog/product/cache/c687aa7517cf01e65c009f6943c2b1e9/1/8/1812.jpg' where codigo = 7;
update producto set imagen = 'https://http2.mlstatic.com/D_NQ_NP_784427-MLA44973459129_022021-O.jpg' where codigo = 8;
update producto set imagen = 'https://http2.mlstatic.com/D_NQ_NP_967841-MLA41904952658_052020-O.jpg' where codigo = 9;
update producto set imagen = 'https://http2.mlstatic.com/D_NQ_NP_978031-MLA31959172038_082019-O.jpg' where codigo = 10;
update producto set imagen = 'https://http2.mlstatic.com/D_NQ_NP_694809-MLA31647193200_072019-O.jpg' where codigo = 11;
update producto set imagen = 'https://http2.mlstatic.com/D_NQ_NP_915070-MLA31045943284_062019-O.jpg' where codigo = 12;
update producto set imagen = 'https://www.doiteargentina.com.ar/wp-content/uploads/2019/11/doite-termo-stanley-verde-nuevo-2020-46721-01.jpg' where codigo = 13;
update producto set imagen = 'https://ardiaprod.vteximg.com.br/arquivos/ids/188719-1000-1000/YERBA-PLAYADITO-SUAVE-1-KG_1.jpg?v=637427630884900000' where codigo = 14;


--agregar columna {porcDescuento} a la tabla {producto}
alter table producto add column porcDescuento integer;
alter table producto alter column porcDescuento set default 0;

update producto set porcDescuento = 10 where codigo = 2;
update producto set porcDescuento = 10 where codigo = 4;
update producto set porcDescuento = 10 where codigo = 6;
update producto set porcDescuento = 15 where codigo = 8;
update producto set porcDescuento = 20 where codigo = 10;
update producto set porcDescuento = 0 where codigo = 1;
update producto set porcDescuento = 0 where codigo = 3;
update producto set porcDescuento = 0 where codigo = 5;
update producto set porcDescuento = 0 where codigo = 7;
update producto set porcDescuento = 0 where codigo = 9;
update producto set porcDescuento = 0 where codigo = 11;
update producto set porcDescuento = 0 where codigo = 12;
update producto set porcDescuento = 0 where codigo = 13;


insert into producto(nombre, stock, precio, descripcion, proveedor, tipo, imagen)
	values('Yerba Mate Playadito', 400, 350, 'Yerba Mate Playadito Tradicional 500g', '3055555555', 5, 'https://www.mate-tee.de/images/product_images/info_images/1655_0.jpg');
	

--agregar columna {carritoActual} a la tabla {usuarop}
alter table usuario add column carritoActual int;



-- Descontar automaticamente la cantidad comprada del stock disponible
CREATE OR REPLACE FUNCTION descontarDeStock() RETURNS TRIGGER AS $funcemp$
DECLARE
BEGIN
	if (new.producto is null) then
		update producto set stock=(stock - new.cantidadproducto) where codigo=new.producto; 
		return new;
	else
		update producto set stock=(stock - new.cantidadproducto) where codigo in
			(select p.codigo from producto p, productoxcombo pc where p.codigo = pc.producto and pc.combo = new.combo)
	end if;	
END; $funcemp$ LANGUAGE plpgsql;

CREATE TRIGGER triggerDescontarDeStock before insert on linea
FOR EACH ROW EXECUTE PROCEDURE descontarDeStock();


-- Devolver el producto al stock disponible al quitarlo del carrito
CREATE OR REPLACE FUNCTION devolverAlStock() RETURNS TRIGGER AS $funcemp$
DECLARE
BEGIN
	if (old.combo is null) then
		update producto set stock=(stock + old.cantidadproducto) where codigo=old.producto; 
		return old;
	else
		update producto set stock=(stock + old.cantidadproducto) where codigo in
			(select p.codigo from producto p, productoxcombo pc where p.codigo = pc.producto and pc.combo = old.combo);
		return old;
	end if;	
END; $funcemp$ LANGUAGE plpgsql;

CREATE TRIGGER triggerDevolverAlStock after delete on linea
FOR EACH ROW EXECUTE PROCEDURE devolverAlStock();

ALTER TABLE linea DROP COLUMN totalproducto;
ALTER TABLE usuario ALTER COLUMN rol SET DEFAULT 4;

--Agregar estado 'suspendido' a las cuentas
alter table usuario add column suspendido boolean default false