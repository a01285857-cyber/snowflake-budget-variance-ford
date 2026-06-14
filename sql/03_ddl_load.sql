-- ============================================================
--  ENTREGABLE 3: DDL & Copy EN SNOWFLAKE
-- Proyecto: Ford Motor Company · Análisis de Variación Presupuestal 2024
-- Base de datos: FORD_DB | Esquema: FINANZAS
-- ============================================================

-- PASO 1: Setup

CREATE DATABASE IF NOT EXISTS FORD_DB;
CREATE SCHEMA IF NOT EXISTS FORD_DB.FINANZAS;
USE DATABASE FORD_DB;
USE SCHEMA FINANZAS;

-- PASO 2: Tablas

-- Tabla Catalogo Áreas (PK)
CREATE TABLE IF NOT EXISTS CATALOGO_AREAS (
    ID_Area             VARCHAR(10)  NOT NULL PRIMARY KEY,
    Nombre_Area         VARCHAR(100),
    Gerente_Responsable VARCHAR(150),
    Centro_Costo_Ppal   VARCHAR(20),
    Direccion           VARCHAR(200),
    Activo              VARCHAR(5)
);

-- Tabla Real

CREATE TABLE IF NOT EXISTS REAL (
    ID_Gasto     NUMBER        NOT NULL PRIMARY KEY,
    Fecha        VARCHAR(20),
    ID_Area      VARCHAR(10)   REFERENCES CATALOGO_AREAS(ID_Area),
    Area         VARCHAR(100),
    Centro_Costo VARCHAR(30),
    Tipo_Gasto   VARCHAR(80),
    Proveedor    VARCHAR(150),
    Importe      VARCHAR(30),
    Aprobado_Por VARCHAR(100)
);

-- ============================================================
-- Datos a considerar:
-- ID_Gasto usa el valor proviniento del CSV fuente, no se genera con AUTOINCREMENT porque regeneralro rompería la integridad con el sistema origen.
-- Fecha se almacena como VARCHAR(20) intencionalmente: el dataset contiene dos formatos mixtos (DD/MM/YY y DD-Mon-YY). Se normalizará en E5.
-- NOT NULL agregado: ID_Area es campo clave de integridad referencial
-- Importe se almacena como VARCHAR(30) intencionalmente: los valores originales incluyen símbolo $ y comas (ej. '$1,234.56'). La conversión numérica se realizará en E5.
-- ============================================================

-- Tabla Presupuesto
CREATE TABLE IF NOT EXISTS PRESUPUESTO (
    ID_Area              VARCHAR(10)  REFERENCES CATALOGO_AREAS(ID_Area),
    Nombre_Area          VARCHAR(100),
    Mes                  VARCHAR(20),
    Num_Mes              NUMBER(2),
    Presupuesto_Aprobado FLOAT,
    Moneda               VARCHAR(5),
    PRIMARY KEY (ID_Area, Num_Mes)
);

-- ============================================================
-- Datos a considerar:
-- Se usa clave natural compuesta (ID_Area, Num_Mes) como PK en lugar de AUTOINCREMENT: cada área tiene exactamente un registro por mes (8 áreas × 12 meses = 96 filas), por lo que la combinación (área, mes) es semánticamente única y permite JOINs directos desde REAL sin necesidad de una llave sustituta.
-- ============================================================

-- PASO 3: Stage interno y carga CSV

CREATE OR REPLACE FILE FORMAT FF_CSV
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    NULL_IF = ('NULL', 'null', '');

-- Nota de carga: los archivos CSV se subieron mediante la interfaz Load Data de Snowsight (drag-and-drop al Stage).

CREATE OR REPLACE STAGE FORD_STAGE
    FILE_FORMAT = FF_CSV
    COMMENT = 'Stage para carga de archivos Ford 2024';

COPY INTO CATALOGO_AREAS
    FROM @FORD_STAGE/Catalogo_Areas.csv
    ON_ERROR = CONTINUE;

COPY INTO REAL
    FROM @FORD_STAGE/Real.csv
    ON_ERROR = CONTINUE;

COPY INTO PRESUPUESTO
    FROM @FORD_STAGE/Presupuesto.csv
    ON_ERROR = CONTINUE;

-- ============================================================
-- Validación de Carga
-- ============================================================

SELECT 'REAL' AS tabla, COUNT(*) AS filas FROM REAL
UNION ALL
SELECT 'PRESUPUESTO', COUNT(*) FROM PRESUPUESTO
UNION ALL
SELECT 'CATALOGO_AREAS', COUNT(*) FROM CATALOGO_AREAS;
