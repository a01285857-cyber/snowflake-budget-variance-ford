FROM PRESUPUESTO;

DESCRIBE TABLE PRESUPUESTO;

-- Distribución mensual: cobertura y monto total por mes
SELECT
    MES,
    NUM_MES,
    COUNT(*)                     AS registros,
    COUNT(DISTINCT ID_Area)      AS areas_cubiertas,
    ROUND(SUM(PRESUPUESTO_APROBADO), 2)  AS presupuesto_total_mes
FROM PRESUPUESTO
GROUP BY MES, NUM_MES
ORDER BY NUM_MES;

-- ============================================================
--  ENTREGABLE 5: Limpieza
-- ============================================================
USE DATABASE FORD_DB;
USE SCHEMA FINANZAS;

-- Verificar contexto
SELECT CURRENT_DATABASE() AS base_de_datos, CURRENT_SCHEMA() AS esquema;

-- ============================================================
-- QUERY 0: Conversión de Importe a tipo numérico
-- ============================================================
ALTER TABLE REAL ADD COLUMN IMPORTE_CLEAN NUMBER(15,2);

UPDATE REAL
SET IMPORTE_CLEAN = TRY_TO_DOUBLE(REPLACE(REPLACE(Importe, '$', ''), ',', ''));

SELECT COUNT(*) AS conversiones_fallidas
FROM REAL
WHERE IMPORTE_CLEAN IS NULL AND Importe IS NOT NULL;
-- ============================================================
-- QUERY 1: Nulos en Centro_Costo
-- ============================================================

-- 1. Diagnóstico
SELECT COUNT(*) AS nulos_centro_costo
FROM REAL
WHERE Centro_Costo IS NULL OR TRIM(Centro_Costo) = '';

-- 2. Limpieza
UPDATE REAL
SET Centro_Costo = '9999-Desconocido'
WHERE Centro_Costo IS NULL OR TRIM(Centro_Costo) = '';

-- 3. Verificación
SELECT COUNT(*) AS nulos_centro_costo_post
FROM REAL
WHERE Centro_Costo IS NULL OR TRIM(Centro_Costo) = '';

-- ============================================================
-- QUERY 2: Fechas en formato incorrecto
-- ============================================================
ALTER TABLE REAL ADD COLUMN FECHA_CLEAN DATE;

UPDATE REAL
SET FECHA_CLEAN = COALESCE(
    -- Formato 1: YYYY-MM-DD  (176 filas esperadas)
    TRY_TO_DATE(Fecha, 'YYYY-MM-DD'),

    -- Formato 2: D/M/YYYY o DD/MM/YYYY, sin ceros a la izquierda (173 filas esperadas)
    -- Se rellenan día y mes a 2 dígitos antes de convertir, para no depender
    -- de qué tan flexible sea TO_DATE con dígitos sueltos.
    TRY_TO_DATE(
        LPAD(SPLIT_PART(Fecha,'/',1),2,'0') || '/' ||
        LPAD(SPLIT_PART(Fecha,'/',2),2,'0') || '/' ||
        SPLIT_PART(Fecha,'/',3),
        'DD/MM/YYYY'
    ),

    -- Formato 3: DD/Mon/YYYY con abreviatura de mes en español (156 filas esperadas)
    TRY_TO_DATE(
        REPLACE(REPLACE(REPLACE(REPLACE(Fecha,'Ene','Jan'),'Abr','Apr'),'Ago','Aug'),'Dic','Dec'),
        'DD/MON/YYYY'
    )
);

-- Verificación
SELECT COUNT(*) AS fechas_sin_convertir
FROM REAL
WHERE FECHA_CLEAN IS NULL;

-- ============================================================
-- QUERY 3: Importes negativos
-- ============================================================
-- Validación: confirmar que no existen importes negativos
SELECT COUNT(*) AS importes_negativos
FROM REAL
WHERE IMPORTE_CLEAN < 0;

-- ============================================================
-- QUERY 4: Duplicados (dos pruebas distintas)
--4a. Duplicados exactos (fila completa, sin PK) — recomendado
-- ============================================================
SELECT
    Fecha, ID_Area, Area, Centro_Costo, Tipo_Gasto, Proveedor, Importe, Aprobado_Por,
    COUNT(*) AS veces_repetido
FROM REAL
GROUP BY ALL
HAVING COUNT(*) > 1;

-- ============================================================
--4b. Hallazgo adicional: ID_Gasto no es único
-- ============================================================
SELECT ID_Gasto, COUNT(*) AS veces
FROM REAL
GROUP BY ID_Gasto
HAVING COUNT(*) > 1;

-- ============================================================
--Hallazgos extra: Tipo_Gasto y Aprobado_Por
-- ============================================================
-- 0. Respaldo antes de reconstruir la tabla 
-- Tipo_Gasto nulo (37 filas)
SELECT COUNT(*) AS nulos_tipo_gasto FROM REAL WHERE Tipo_Gasto IS NULL;

UPDATE REAL SET Tipo_Gasto = 'Sin Clasificar' WHERE Tipo_Gasto IS NULL;

-- Aprobado_Por nulo o 'Pending' (172 filas)
SELECT COUNT(*) AS sin_aprobador FROM REAL
WHERE Aprobado_Por IS NULL OR Aprobado_Por = 'Pending';

UPDATE REAL SET Aprobado_Por = 'Pendiente de Aprobación'
WHERE Aprobado_Por IS NULL OR Aprobado_Por = 'Pending';

-- ============================================================
--Problema 4b: corrección de ID_Gasto
-- ============================================================
-- Respaldo
CREATE TABLE REAL_BACKUP CLONE REAL;

-- Reconstrucción con ID único
CREATE OR REPLACE TABLE REAL AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ID_Gasto, FECHA_CLEAN) AS ID_GASTO_UNICO,
    ID_Gasto AS ID_GASTO_ORIGINAL,
    Fecha, FECHA_CLEAN, ID_Area, Area, Centro_Costo, Tipo_Gasto, Proveedor,
    Importe, IMPORTE_CLEAN, Aprobado_Por
FROM REAL;

SELECT COUNT(*) AS total, COUNT(DISTINCT ID_GASTO_UNICO) AS unicos FROM REAL;

-- ============================================================
--Re-ejecutar profiling (antes/después)
-- ============================================================
SELECT
    COUNT(*)                                                AS total_filas,
    COUNT(*) - COUNT(IMPORTE_CLEAN)                         AS nulos_importe_clean,
    COUNT(*) - COUNT(FECHA_CLEAN)                           AS nulos_fecha_clean,
    COUNT(*) - COUNT(Centro_Costo)                          AS nulos_centro_costo,
    COUNT(*) - COUNT(Tipo_Gasto)                            AS nulos_tipo_gasto,
    SUM(CASE WHEN IMPORTE_CLEAN < 0 THEN 1 ELSE 0 END)      AS importes_negativos,
    COUNT(DISTINCT ID_GASTO_UNICO)                          AS ids_unicos,
    MIN(IMPORTE_CLEAN)                                      AS importe_min,
    MAX(IMPORTE_CLEAN)                                      AS importe_max,
    ROUND(AVG(IMPORTE_CLEAN),2)                             AS importe_promedio
FROM REAL;
