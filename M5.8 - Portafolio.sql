-- =============================================
-- A) DDL - CREACIÓN DE TABLAS
-- =============================================

-- Si las tablas ya existen, se eliminan para evitar errores al re-ejecutar el script
DROP TABLE IF EXISTS orden_items;
DROP TABLE IF EXISTS ordenes;
DROP TABLE IF EXISTS inventario;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS usuarios;

-- 1. Tabla: usuarios
CREATE TABLE usuarios (
    id_usuario SERIAL PRIMARY KEY,
    nombre TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    creado_en TIMESTAMP DEFAULT now()
);

-- 2. Tabla: productos
CREATE TABLE productos (
    id_producto SERIAL PRIMARY KEY,
    nombre TEXT NOT NULL,
    precio NUMERIC(10,2) NOT NULL CHECK (precio >= 0),
    activo BOOLEAN DEFAULT TRUE
);

-- 3. Tabla: inventario
-- Relación 1 a 1 con productos (PK es también FK)
CREATE TABLE inventario (
    id_producto INT PRIMARY KEY REFERENCES productos(id_producto) ON DELETE CASCADE,
    stock INT NOT NULL CHECK (stock >= 0)
);

-- 4. Tabla: ordenes
CREATE TABLE ordenes (
    id_orden SERIAL PRIMARY KEY,
    id_usuario INT REFERENCES usuarios(id_usuario) ON DELETE RESTRICT,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    total NUMERIC(12,2) DEFAULT 0
);

-- 5. Tabla: orden_items
CREATE TABLE orden_items (
    id_item SERIAL PRIMARY KEY,
    id_orden INT REFERENCES ordenes(id_orden) ON DELETE CASCADE,
    id_producto INT REFERENCES productos(id_producto) ON DELETE RESTRICT,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario >= 0)
);

-- =============================================
-- B) DML - POBLAMIENTO INICIAL (INSERTs)
-- =============================================

-- Insertar Usuarios
INSERT INTO usuarios (nombre, email) VALUES
('Juan Luis Pérez', 'juan.perez@example.com'),
('Josefa García', 'josefa.garcia@example.com'),
('Matías López', 'matias.lopez@example.com'),
('Ana María Rodríguez', 'ana.rodriguez@example.com'),
('Luis Miguel Martínez', 'luis.martinez@example.com');

-- Insertar Productos
INSERT INTO productos (nombre, precio, activo) VALUES
('Laptop Gamer', 1990000, TRUE),
('Mouse Inalámbrico', 25000, TRUE),
('Teclado Mecánico', 18000, TRUE),
('Monitor 24"', 150000, TRUE),
('Auriculares Bluetooth', 45000, TRUE);

-- Insertar Inventario (Stock inicial)
-- Asumimos IDs 1 a 5 porque son SERIAL y acabamos de insertar
INSERT INTO inventario (id_producto, stock) VALUES
(1, 10),  -- Laptop
(2, 50),  -- Mouse
(3, 30),  -- Teclado
(4, 15),  -- Monitor
(5, 5);   -- Auriculares (stock bajo intencional para pruebas)

-- Insertar Órdenes (con fechas variadas)
-- NOTA: Insertamos el total en 0 inicalmente, para calcularlo después automáticamente
INSERT INTO ordenes (id_usuario, fecha, total) VALUES
(1, '2025-10-01', 0), -- Juan Luis
(2, '2025-10-02', 0), -- Josefa
(3, '2025-10-03', 0), -- Matías
(1, '2026-01-05', 0), -- Juan Luis
(4, '2026-01-10', 0); -- Ana María

-- Insertar Items de Órdenes
-- Orden 1 (Juan Luis): Laptop (1) y Mouse (2)
INSERT INTO orden_items (id_orden, id_producto, cantidad, precio_unitario) VALUES
(1, 1, 1, 1990000),
(1, 2, 1, 25000);

-- Orden 2 (Josefa): Monitor (4)
INSERT INTO orden_items (id_orden, id_producto, cantidad, precio_unitario) VALUES
(2, 4, 1, 150000);

-- Orden 3 (Matías): Teclado (3)
INSERT INTO orden_items (id_orden, id_producto, cantidad, precio_unitario) VALUES
(3, 3, 1, 18000);

-- Orden 4 (Juan Luis): Auriculares (5)
INSERT INTO orden_items (id_orden, id_producto, cantidad, precio_unitario) VALUES
(4, 5, 1, 45000);

-- Orden 5 (Ana María): Mouse (2)
INSERT INTO orden_items (id_orden, id_producto, cantidad, precio_unitario) VALUES
(5, 2, 1, 25000);

-- -------------------------------------------------------------------------
-- CÁLCULO DE TOTALES AUTOMÁTICO
-- -------------------------------------------------------------------------
-- Actualizamos la tabla 'ordenes' sumando (cantidad * precio_unitario) de sus items
UPDATE ordenes
SET total = (
    SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
    FROM orden_items
    WHERE orden_items.id_orden = ordenes.id_orden
);

-- =============================================
-- D) CONSULTAS REQUERIDAS (Queries)
-- =============================================

select* from productos

-- 1. Oferta verano: actualizar precio –20%
UPDATE productos 
SET precio = ROUND(precio * 0.80, 2);


-- 2. Stock crítico (<= 5 unidades)
SELECT p.id_producto, p.nombre, i.stock
FROM inventario i
JOIN productos p USING (id_producto)
WHERE i.stock <= 5;


-- 3. Simular compra (al menos 3 productos): calcular subtotal, agregar IVA y mostrar total
-- Usa el IVA que indique el docente (por defecto, 19%).

-- 1) Crear la orden
INSERT INTO ordenes (id_usuario, fecha) VALUES (1, '2022-12-15') RETURNING id_orden;

-- 2) Insertar ítems 
INSERT INTO orden_items (id_orden, id_producto, cantidad, precio_unitario) VALUES 
(7, 1, 1, 1592000), -- Laptop (1990000 - 20%)
(7, 2, 2, 20000),   -- 2 Mouses (25000 - 20%)
(7, 3, 1, 14400);   -- Teclado (18000 - 20%)

-- 3) Totales
SELECT SUM(oi.cantidad*oi.precio_unitario) AS subtotal,
       ROUND(SUM(oi.cantidad*oi.precio_unitario)*1.19, 2) AS total_con_iva
FROM orden_items oi
WHERE oi.id_orden = 7;

-- 3.1. Ver detalle de la orden N°7
SELECT 
    o.id_orden,
    o.fecha,
    u.nombre AS cliente,
    p.nombre AS producto,
    oi.cantidad,
    oi.precio_unitario,
    (oi.cantidad * oi.precio_unitario) AS subtotal_item
FROM ordenes o
JOIN usuarios u ON o.id_usuario = u.id_usuario
JOIN orden_items oi ON o.id_orden = oi.id_orden
JOIN productos p ON oi.id_producto = p.id_producto
WHERE o.id_orden = 7;


-- 4. Total de ventas diciembre 2022
SELECT SUM(oi.cantidad * oi.precio_unitario) AS total_neto
FROM ordenes o
JOIN orden_items oi ON oi.id_orden = o.id_orden
WHERE o.fecha BETWEEN '2022-12-01' AND '2022-12-31';


-- 5. Comportamiento del usuario con más compras (2022)
-- “Más compras” = mayor número de órdenes.
WITH por_usuario AS (
  SELECT id_usuario, COUNT(*) AS ordenes
  FROM ordenes
  WHERE fecha BETWEEN '2022-01-01' AND '2022-12-31'
  GROUP BY id_usuario
)
SELECT * FROM por_usuario
ORDER BY ordenes DESC
LIMIT 1;


-- (Opcional) Listar órdenes e ítems del usuario con más compras en 2022
WITH top_user AS (
    SELECT id_usuario
    FROM ordenes
    WHERE fecha BETWEEN '2022-01-01' AND '2022-12-31'
    GROUP BY id_usuario
    ORDER BY COUNT(*) DESC
    LIMIT 1
)
SELECT 
    u.nombre AS cliente, 
    o.id_orden, 
    o.fecha, 
    p.nombre AS producto, 
    oi.cantidad, 
    oi.precio_unitario,
    (oi.cantidad * oi.precio_unitario) AS subtotal
FROM top_user tu
JOIN usuarios u ON u.id_usuario = tu.id_usuario
JOIN ordenes o ON o.id_usuario = tu.id_usuario
JOIN orden_items oi ON o.id_orden = oi.id_orden
JOIN productos p ON oi.id_producto = p.id_producto
WHERE o.fecha BETWEEN '2022-01-01' AND '2022-12-31'
ORDER BY o.fecha, o.id_orden;
