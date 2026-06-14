
--3. Vista ejecutiva reutilizable
CREATE OR REPLACE VIEW VW_VARIANZA_FORD AS
WITH real_trimestre AS (
    SELECT ID_Area, QUARTER(FECHA_CLEAN) AS Trimestre, SUM(IMPORTE_CLEAN) AS Total_Real
    FROM REAL WHERE FECHA_CLEAN IS NOT NULL GROUP BY ID_Area, QUARTER(FECHA_CLEAN)
),
ppto_trimestre AS (
    SELECT ID_Area, CEIL(Num_Mes/3.0) AS Trimestre, SUM(Presupuesto_Aprobado) AS Total_Presupuesto
    FROM PRESUPUESTO GROUP BY ID_Area, CEIL(Num_Mes/3.0)
)
SELECT a.Nombre_Area, a.Direccion, r.Trimestre, r.Total_Real, p.Total_Presupuesto,
       r.Total_Real - p.Total_Presupuesto AS Varianza,
       ROUND((r.Total_Real - p.Total_Presupuesto)/NULLIF(p.Total_Presupuesto,0)*100,2) AS Pct_Varianza
FROM real_trimestre r
JOIN ppto_trimestre p ON r.ID_Area=p.ID_Area AND r.Trimestre=p.Trimestre
JOIN CATALOGO_AREAS a ON r.ID_Area=a.ID_Area;

-- ============================================================
-- VIEW
-- ============================================================
CREATE OR REPLACE VIEW VW_VARIANZA_FORD AS
SELECT
    a.Nombre_Area,
    a.Direccion,
    p.Mes,
    p.Num_Mes,
    r.Tipo_Gasto,
    ROUND(SUM(r.Importe_Num), 2)                                          AS Total_Real,
    ROUND(p.Presupuesto_Aprobado, 2)                                      AS Total_Ppto,
    ROUND(SUM(r.Importe_Num) - p.Presupuesto_Aprobado, 2)                AS Varianza,
    ROUND(
        (SUM(r.Importe_Num) - p.Presupuesto_Aprobado)
        / NULLIF(p.Presupuesto_Aprobado, 0) * 100
    , 2)                                                                   AS Pct_Varianza,
    CASE
        WHEN SUM(r.Importe_Num) > p.Presupuesto_Aprobado THEN 'SOBRE'
        WHEN SUM(r.Importe_Num) < p.Presupuesto_Aprobado THEN 'BAJO'
        ELSE 'EN META'
    END AS Status_Budget
FROM REAL r
JOIN CATALOGO_AREAS a ON r.ID_Area = a.ID_Area
JOIN PRESUPUESTO p    ON r.ID_Area = p.ID_Area
                     AND MONTH(r.Fecha_Clean) = p.Num_Mes
WHERE r.Fecha_Clean IS NOT NULL
  AND r.Importe_Num IS NOT NULL
GROUP BY a.Nombre_Area, a.Direccion, p.Mes, p.Num_Mes, r.Tipo_Gasto, p.Presupuesto_Aprobado
ORDER BY p.Num_Mes, Varianza;

-- Verificar la vista
SELECT * FROM VW_VARIANZA_FORD LIMIT 10;