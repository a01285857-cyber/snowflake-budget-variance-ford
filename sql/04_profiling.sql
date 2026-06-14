-- ============================================================
--  ENTREGABLE 4: Data Profiling
-- ============================================================
USE DATABASE FORD_DB;
USE SCHEMA FINANZAS;

-- Verificar contexto
SELECT CURRENT_DATABASE() AS base_de_datos, CURRENT_SCHEMA() AS esquema;

-- ============================================================
-- QUERY 1: Conteo de filas por tabla
-- ============================================================
SELECT 'REAL'            AS tabla, COUNT(*) AS total_filas FROM REAL
UNION ALL
SELECT 'PRESUPUESTO',             COUNT(*)               FROM PRESUPUESTO
UNION ALL
SELECT 'CATALOGO_AREAS',          COUNT(*)               FROM CATALOGO_AREAS;

-- ============================================================
-- QUERY 2: Nulos por columna en tabla REAL
-- ============================================================

SELECT
    COUNT(*)                           AS total_filas,
    COUNT(*) - COUNT(ID_Gasto)         AS nulos_ID_Gasto,
    COUNT(*) - COUNT(Fecha)            AS nulos_Fecha,
    COUNT(*) - COUNT(ID_Area)          AS nulos_ID_Area,
    COUNT(*) - COUNT(Area)             AS nulos_Area,
    COUNT(*) - COUNT(Centro_Costo)     AS nulos_Centro_Costo,   
    COUNT(*) - COUNT(Tipo_Gasto)       AS nulos_Tipo_Gasto,
    COUNT(*) - COUNT(Proveedor)        AS nulos_Proveedor,
    COUNT(*) - COUNT(Importe)          AS nulos_Importe,
    COUNT(*) - COUNT(Aprobado_Por)     AS nulos_Aprobado_Por
FROM REAL;

-- ============================================================
-- QUERY 3 · Estadísticas descriptivas de Importe
-- (limpiamos $ y comas antes de calcular)
-- La columna Importe fue cargada  como VARCHAR ya que contiene caracteres no numericos ($,comas). De manera que para calcular estadísticas sin modificar la tabla original, se aplica limpieza en memoria como REPLACE() para eliminar los símbolos y TRY_TO_DOUBLE() para convertir el texto a número. Esta información es temporal ya que la limpieza se hara en el Entregable 5 y no altera los datos.
-- ============================================================
SELECT
    COUNT(*)                                                            AS total_registros,
    MIN(TRY_TO_DOUBLE(REPLACE(REPLACE(Importe, '$', ''), ',', '')))    AS importe_min,
    MAX(TRY_TO_DOUBLE(REPLACE(REPLACE(Importe, '$', ''), ',', '')))    AS importe_max,
    ROUND(
      AVG(TRY_TO_DOUBLE(REPLACE(REPLACE(Importe, '$', ''), ',', '')))
    , 2)                                                                AS importe_promedio,
    ROUND(
      STDDEV(TRY_TO_DOUBLE(REPLACE(REPLACE(Importe, '$', ''), ',', '')))
    , 2)                                                                AS importe_stddev,
    PERCENTILE_CONT(0.5) WITHIN GROUP
        (ORDER BY TRY_TO_DOUBLE(REPLACE(REPLACE(Importe, '$', ''), ',', '')))
                                                                        AS importe_mediana,
    SUM(CASE
            WHEN TRY_TO_DOUBLE(REPLACE(REPLACE(Importe, '$', ''), ',', '')) < 0
            THEN 1 ELSE 0
        END)                                                            AS importes_negativos
FROM REAL;

-- ============================================================
-- QUERY 4A: Distribución por Trimestre
-- Se calcula el trimestre a partir de la columna Fecha ya que el dataset no incluye una columna TRIMESTRE explícita.
-- ============================================================
SELECT
    QUARTER(
        CASE
            WHEN Fecha RLIKE '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{2}$'
                THEN TO_DATE(Fecha, 'DD-MON-YY')
            WHEN Fecha RLIKE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$'
                THEN TO_DATE(Fecha, 'DD/MM/YY')
        END
    )                   AS trimestre,
    COUNT(*)            AS cantidad
FROM REAL
GROUP BY 1
ORDER BY 1;

-- HALLAZGO: 53 registros aparecen como NULL en trimestre.
-- Corresponden a fechas en formato DD-Mon-YY (ej. 01-Jun-24) que no pudieron convertirse correctamente debido a inconsistencias en el formato de la columna Fecha. Estos registros serán estandarizados en Entregable 5.

-- ============================================================
-- QUERY 4B: Rango de fechas en tabla REAL
-- Documenta la cobertura temporal del dataset (requerido en la tabla resumen del reporte de profiling).
-- ============================================================
SELECT
    MIN(
        CASE
            WHEN Fecha RLIKE '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{2}$'
                THEN TO_DATE(Fecha, 'DD-MON-YY')
            WHEN Fecha RLIKE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$'
                THEN TO_DATE(Fecha, 'DD/MM/YY')
        END
    ) AS fecha_minima,
    MAX(
        CASE
            WHEN Fecha RLIKE '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{2}$'
                THEN TO_DATE(Fecha, 'DD-MON-YY')
            WHEN Fecha RLIKE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$'
                THEN TO_DATE(Fecha, 'DD/MM/YY')
        END
    ) AS fecha_maxima,
    DATEDIFF('day',
        MIN(
            CASE
                WHEN Fecha RLIKE '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{2}$'
                    THEN TO_DATE(Fecha, 'DD-MON-YY')
                WHEN Fecha RLIKE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$'
                    THEN TO_DATE(Fecha, 'DD/MM/YY')
            END
        ),
        MAX(
            CASE
                WHEN Fecha RLIKE '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{2}$'
                    THEN TO_DATE(Fecha, 'DD-MON-YY')
                WHEN Fecha RLIKE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$'
                    THEN TO_DATE(Fecha, 'DD/MM/YY')
            END
        )
    ) AS dias_cobertura
FROM REAL;

-- ============================================================
-- QUERY 5A: Valores distintos clave en tabla REAL
-- ============================================================
SELECT
    COUNT(DISTINCT ID_Area)      AS areas_distintas,
    COUNT(DISTINCT Tipo_Gasto)   AS tipos_gasto,
    COUNT(DISTINCT Proveedor)    AS proveedores,
    COUNT(DISTINCT Aprobado_Por) AS aprobadores
FROM REAL;

-- ============================================================
-- QUERY 5B: Estructura y distribución de la tabla PRESUPUESTO
-- Objetivo: identificar los valores únicos y la cobertura de la tabla PRESUPUESTO para validar que el dataset está completo: todas las áreas cubiertas en todos los meses, consistencia de moneda y total presupuestado por periodo.
-- ============================================================

-- Conteo de valores distintos por dimensión
SELECT
    COUNT(DISTINCT ID_Area)   AS areas_distintas,
    COUNT(DISTINCT MES)       AS meses_distintos,
    COUNT(DISTINCT MONEDA)    AS monedas_distintas
