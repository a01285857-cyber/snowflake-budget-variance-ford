-- ============================================================
--  ENTREGABLE 6: Queries Multi-tabla
-- ============================================================
USE DATABASE FORD_DB;
USE SCHEMA FINANZAS;

-- Verificar contexto
SELECT CURRENT_DATABASE() AS base_de_datos, CURRENT_SCHEMA() AS esquema;
-- ============================================================
-- Query maestra
-- ============================================================
WITH real_trimestre AS (
    SELECT
        ID_Area,
        QUARTER(FECHA_CLEAN) AS Trimestre,
        SUM(IMPORTE_CLEAN)   AS Total_Real
    FROM REAL
    WHERE FECHA_CLEAN IS NOT NULL
    GROUP BY ID_Area, QUARTER(FECHA_CLEAN)
),
ppto_trimestre AS (
    SELECT
        ID_Area,
        CEIL(Num_Mes / 3.0)        AS Trimestre,
        SUM(Presupuesto_Aprobado)  AS Total_Presupuesto
    FROM PRESUPUESTO
    GROUP BY ID_Area, CEIL(Num_Mes / 3.0)
)
SELECT
    a.Nombre_Area,
    a.Direccion,
    r.Trimestre,
    r.Total_Real,
    p.Total_Presupuesto,
    r.Total_Real - p.Total_Presupuesto AS Varianza,
    ROUND(
        (r.Total_Real - p.Total_Presupuesto) / NULLIF(p.Total_Presupuesto,0) * 100
    , 2) AS Pct_Varianza
FROM real_trimestre r
JOIN ppto_trimestre p
    ON r.ID_Area = p.ID_Area AND r.Trimestre = p.Trimestre
JOIN CATALOGO_AREAS a
    ON r.ID_Area = a.ID_Area
ORDER BY a.Nombre_Area, r.Trimestre;

-- ============================================================
-- QUERY 1 · Top 5 mayor sobregiro (gasto > presupuesto)
-- ============================================================
WITH real_trimestre AS (
    SELECT ID_Area, QUARTER(FECHA_CLEAN) AS Trimestre, SUM(IMPORTE_CLEAN) AS Total_Real
    FROM REAL WHERE FECHA_CLEAN IS NOT NULL
    GROUP BY ID_Area, QUARTER(FECHA_CLEAN)
),
ppto_trimestre AS (
    SELECT ID_Area, CEIL(Num_Mes/3.0) AS Trimestre, SUM(Presupuesto_Aprobado) AS Total_Presupuesto
    FROM PRESUPUESTO
    GROUP BY ID_Area, CEIL(Num_Mes/3.0)
)
SELECT
    a.Nombre_Area,
    r.Trimestre,
    r.Total_Real,
    p.Total_Presupuesto,
    r.Total_Real - p.Total_Presupuesto AS Varianza,
    ROUND((r.Total_Real - p.Total_Presupuesto) / NULLIF(p.Total_Presupuesto,0) * 100, 2) AS Pct_Varianza
FROM real_trimestre r
JOIN ppto_trimestre p ON r.ID_Area = p.ID_Area AND r.Trimestre = p.Trimestre
JOIN CATALOGO_AREAS a ON r.ID_Area = a.ID_Area
ORDER BY Varianza DESC LIMIT 5;

-- ============================================================
-- QUERY 2: Comparativa por trimestre
-- ============================================================
WITH real_trimestre AS (
    SELECT QUARTER(FECHA_CLEAN) AS Trimestre, SUM(IMPORTE_CLEAN) AS Total_Real
    FROM REAL WHERE FECHA_CLEAN IS NOT NULL
    GROUP BY QUARTER(FECHA_CLEAN)
),
ppto_trimestre AS (
    SELECT CEIL(Num_Mes/3.0) AS Trimestre, SUM(Presupuesto_Aprobado) AS Total_Presupuesto
    FROM PRESUPUESTO
    GROUP BY CEIL(Num_Mes/3.0)
)
SELECT
    r.Trimestre,
    r.Total_Real,
    p.Total_Presupuesto,
    r.Total_Real - p.Total_Presupuesto AS Varianza,
    CASE WHEN r.Total_Real > p.Total_Presupuesto THEN 'Sí' ELSE 'No' END AS Gasto_Supero_Presupuesto
FROM real_trimestre r
JOIN ppto_trimestre p ON r.Trimestre = p.Trimestre
ORDER BY r.Trimestre;

-- ============================================================
-- QUERY 3: Áreas sin registros en Real
-- ============================================================
-- 1. ¿Tienes las 96 filas esperadas (8 áreas x 12 meses)?
SELECT COUNT(*) AS total_filas FROM PRESUPUESTO;

-- 2. ¿Existe el registro de A04/Agosto?
SELECT * FROM PRESUPUESTO WHERE ID_Area='A04' AND Num_Mes=8;

INSERT INTO PRESUPUESTO (ID_Area, Nombre_Area, Mes, Num_Mes, Presupuesto_Aprobado, Moneda)
VALUES ('A04','Logística','Agosto',8,836594.11,'MXN');

-- ============================================================
--Vista ejecutiva + desglose por Tipo_Gasto
-- ============================================================
--1. Desglose complementario por Tipo_Gasto (resuelve la Ambigüedad 2 mostrando el detalle, sin comparar contra un presupuesto que no existe a ese nivel, etiquetado claramente como informativo):
SELECT
    a.Nombre_Area,
    QUARTER(r.FECHA_CLEAN) AS Trimestre,
    r.Tipo_Gasto,
    SUM(r.IMPORTE_CLEAN) AS Total_Real
FROM REAL r
JOIN CATALOGO_AREAS a ON r.ID_Area = a.ID_Area
WHERE r.FECHA_CLEAN IS NOT NULL
GROUP BY a.Nombre_Area, QUARTER(r.FECHA_CLEAN), r.Tipo_Gasto
ORDER BY a.Nombre_Area, Trimestre, Total_Real DESC;

--2. Validación cruzada de totales: confirma que SUM(Total_Real) de la query maestra coincide con SUM(IMPORTE_CLEAN) directo de REAL (detecta si hubo fan-out o filas perdidas):
SELECT SUM(IMPORTE_CLEAN) AS total_real_directo FROM REAL WHERE FECHA_CLEAN IS NOT NULL;
