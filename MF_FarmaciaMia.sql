CREATE DATABASE Farmacia_MIA;
GO

USE Farmacia_MIA;
GO


--Proveedor
CREATE TABLE Proveedor (
    ID_Proveedor INT PRIMARY KEY IDENTITY(1,1),
    Nombre VARCHAR(30) NOT NULL,
    Direccion VARCHAR(250),
    Telefono VARCHAR(100),
    Email VARCHAR(150) NOT NULL
);


--Usuario 
CREATE TABLE Usuario(
	 ID_Usuario INT PRIMARY KEY IDENTITY(1,1),
	 Correo VARCHAR(100) NOT NULL,
	 Clave_Hash VARBINARY(64) NOT NULL

);
-- Usuario debe tener una restricción de unicidad (UNIQUE) para que dos usuarios no se puedan registrar con el mismo correo.
ALTER TABLE Usuario
ADD CONSTRAINT UQ_Usuario_Correo UNIQUE (Correo);

CREATE TABLE Rol (
    ID_Rol INT PRIMARY KEY IDENTITY(1,1),
    NombreRol VARCHAR(50) NOT NULL UNIQUE
);

ALTER TABLE Usuario
ADD ID_Rol INT;

ALTER TABLE Usuario
ADD CONSTRAINT FK_Usuario_Rol FOREIGN KEY (ID_Rol)
    REFERENCES Rol(ID_Rol);


--Cliente
CREATE TABLE Cliente(
	ID_Cliente INT PRIMARY KEY IDENTITY(1,1),
	Nombre VARCHAR(30) NOT NULL,
    Direccion VARCHAR(250),
    Telefono VARCHAR(100)
);


--Promocion
CREATE TABLE Promocion(
	ID_Promocion INT PRIMARY KEY IDENTITY(1,1),
	Descripcion VARCHAR(250),
    Fecha_Inicio DATE NOT NULL,
    Fecha_Fin DATE NOT NULL,
    Descuento DECIMAL(5,2) NOT NULL DEFAULT(0), -- porcentaje 0.00 - 100.00
    CONSTRAINT CK_Promocion_Descuento CHECK(Descuento >= 0 AND Descuento <= 100),
    CONSTRAINT CK_Promocion_Fechas CHECK (Fecha_Fin >= Fecha_Inicio)
);

--Medicamento	Sin stock
CREATE TABLE Medicamento (
    ID_Medicamento INT PRIMARY KEY IDENTITY(1,1),
    ID_Proveedor INT NOT NULL,
    Nombre VARCHAR(30) NOT NULL,
    Descripcion VARCHAR(500),
    Precio DECIMAL(10,2) NOT NULL CHECK (Precio >= 0),

    CONSTRAINT FK_Medicamento_Proveedor FOREIGN KEY (ID_Proveedor)
        REFERENCES Proveedor(ID_Proveedor)
        ON UPDATE NO ACTION --No poder cambiar el ID del Proveedor si está en uso
        ON DELETE NO ACTION--No poder borrar un proveedor si todavía tiene medicamentos asociados.
);


--Inventario (registro actual por medicamento)  Stock actual
CREATE TABLE Inventario (
    ID_Inventario INT PRIMARY KEY IDENTITY(1,1),
    ID_Medicamento INT NOT NULL UNIQUE, -- 1:1 con Medicamento (un registro por medicamento)
    Cantidad_Disponible INT NOT NULL DEFAULT(0) CHECK (Cantidad_Disponible >= 0),
    Punto_Reposicion INT NOT NULL DEFAULT(0) CHECK (Punto_Reposicion >= 0),

    CONSTRAINT FK_Inventario_Medicamento FOREIGN KEY (ID_Medicamento)
        REFERENCES Medicamento(ID_Medicamento)
        ON DELETE CASCADE
);


--InventarioHistorico (movimientos) 
CREATE TABLE InventarioHistorico (
    ID_Inventario_Historico INT PRIMARY KEY IDENTITY(1,1),
    ID_Usuario INT NOT NULL,
    ID_Medicamento INT NOT NULL,
    Fecha_Movimiento DATETIME NOT NULL DEFAULT(GETDATE()),
    Tipo_Movimiento VARCHAR(20) NOT NULL DEFAULT('Entrada'), -- 'Entrada','Salida','Ajuste'
    Cantidad INT NOT NULL CHECK (Cantidad >= 0),
    CONSTRAINT CK_TipoMovimiento CHECK (Tipo_Movimiento IN ('Entrada','Salida','Ajuste')),

    CONSTRAINT FK_InventarioHistorico_Usuario FOREIGN KEY (ID_Usuario)
        REFERENCES Usuario(ID_Usuario)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT FK_InventarioHistorico_Medicamento FOREIGN KEY (ID_Medicamento)
        REFERENCES Medicamento(ID_Medicamento)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);


--Factura (se crea primero)
CREATE TABLE Factura (
    ID_Factura INT IDENTITY(1,1) PRIMARY KEY,
    Numero_Factura VARCHAR(50) UNIQUE NOT NULL,
    Fecha DATETIME NOT NULL DEFAULT(GETDATE()),
    Monto_Total DECIMAL(12,2) NOT NULL CHECK (Monto_Total >= 0)
);


--Venta (con FK hacia Factura) 
CREATE TABLE Venta (
    ID_Venta INT PRIMARY KEY IDENTITY(1,1),
    ID_Cliente INT NULL,
    ID_Usuario INT NOT NULL,     -- quien registró la venta
    ID_Factura INT UNIQUE,       -- 1:1 con Factura
    Fecha DATETIME NOT NULL DEFAULT(GETDATE()),
    IVA DECIMAL(5,2) NOT NULL DEFAULT(0),

    CONSTRAINT FK_Venta_Cliente FOREIGN KEY (ID_Cliente)
        REFERENCES Cliente(ID_Cliente)
        ON UPDATE NO ACTION
        ON DELETE SET NULL,

    CONSTRAINT FK_Venta_Usuario FOREIGN KEY (ID_Usuario)
        REFERENCES Usuario(ID_Usuario)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT FK_Venta_Factura FOREIGN KEY (ID_Factura)
        REFERENCES Factura(ID_Factura)
        ON UPDATE NO ACTION
        ON DELETE CASCADE --Si borramos una factura → también se borra la venta
);


--Detalle_Venta: PK compuesta ID_Venta + ID_Medicamento 
CREATE TABLE Detalle_Venta (
    ID_Venta INT NOT NULL,
    ID_Medicamento INT NOT NULL,
    Cantidad INT NOT NULL CHECK (Cantidad > 0),
    PrecioUnitario DECIMAL(10,2) NOT NULL CHECK (PrecioUnitario >= 0),
    ID_Promocion INT NULL,  -- si aplica promoción
    CONSTRAINT PK_DetalleVenta PRIMARY KEY (ID_Venta, ID_Medicamento),

    CONSTRAINT FK_DetalleVenta_Venta FOREIGN KEY (ID_Venta)
        REFERENCES Venta(ID_Venta)
        ON UPDATE NO ACTION
        ON DELETE CASCADE,

    CONSTRAINT FK_DetalleVenta_Medicamento FOREIGN KEY (ID_Medicamento)
        REFERENCES Medicamento(ID_Medicamento)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT FK_DetalleVenta_Promocion FOREIGN KEY (ID_Promocion)
        REFERENCES Promocion(ID_Promocion)
        ON UPDATE NO ACTION
        ON DELETE SET NULL
);

CREATE TABLE MedicamentoPromocion(
    ID_Medicamento INT NOT NULL,
    ID_Promocion INT NOT NULL,
    CONSTRAINT PK_MedicamentoPromocion PRIMARY KEY (ID_Medicamento, ID_Promocion),
    FOREIGN KEY (ID_Medicamento) REFERENCES Medicamento(ID_Medicamento),
    FOREIGN KEY (ID_Promocion) REFERENCES Promocion(ID_Promocion)
);

--Devolucion
CREATE TABLE Devolucion (
    ID_Devolucion INT PRIMARY KEY IDENTITY(1,1),
    ID_Medicamento INT NOT NULL,
    ID_Venta INT NOT NULL,
    ID_Usuario INT NOT NULL,    -- quien procesó la devolución
    Fecha DATETIME NOT NULL DEFAULT(GETDATE()),
    Motivo VARCHAR(300),
    Cantidad INT NOT NULL CHECK (Cantidad > 0),

    CONSTRAINT FK_Devolucion_Medicamento FOREIGN KEY (ID_Medicamento)
        REFERENCES Medicamento(ID_Medicamento)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT FK_Devolucion_Venta FOREIGN KEY (ID_Venta)
        REFERENCES Venta(ID_Venta)
        ON UPDATE NO ACTION
        ON DELETE CASCADE,

    CONSTRAINT FK_Devolucion_Usuario FOREIGN KEY (ID_Usuario)
        REFERENCES Usuario(ID_Usuario)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);






