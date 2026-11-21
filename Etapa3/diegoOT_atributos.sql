-- =====================================================================
-- OT Consulting · Avance Reto Etapa 3: Tratamiento y Acondicionamiento
-- Diego Perez Sánchez · A01236912 · Grupo 301
--
-- Fórmulas de los atributos nuevos e indicadores, escritas en SQL
-- (SQLite) sobre las tablas acondicionadas que exporta el notebook
-- (carpeta salida/). Se ejecuta con: python diegoOT_ejecutar_sql.py
--
-- Fecha de corte: 2026-11-17. Horas por mes: 160 (40 h x 4 semanas).
-- Los booleanos vienen del CSV como texto 'True' / 'False'.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Atributos de colaboradores (se recalculan para comprobar el notebook)
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_colaboradores_atributos;
CREATE VIEW v_colaboradores_atributos AS
SELECT
    id_colaborador,
    estatus_corte,
    -- Estatus al corte: BAJA si la fuente dice Baja o la baja ya ocurrió;
    -- ACTIVO (BAJA PROGRAMADA) si la fecha de baja es posterior al corte.
    CASE
        WHEN estatus_origen = 'BAJA'
          OR (estatus_origen = 'ACTIVO' AND fecha_baja <> '' AND fecha_baja <= '2026-11-17') THEN 'BAJA'
        WHEN estatus_origen = 'ACTIVO' AND fecha_baja > '2026-11-17' THEN 'ACTIVO (BAJA PROGRAMADA)'
        ELSE 'ACTIVO'
    END AS estatus_corte_sql,
    -- Antigüedad (años) = (fecha de baja o corte − fecha de incorporación) / 365.25
    -- Nula si es una baja sin fecha (no se imputa).
    antiguedad_anios,
    CASE
        WHEN baja_sin_fecha = 'True' OR fecha_incorporacion = '' THEN NULL
        ELSE ROUND((julianday(COALESCE(NULLIF(fecha_baja, ''), '2026-11-17'))
                    - julianday(fecha_incorporacion)) / 365.25, 1)
    END AS antiguedad_anios_sql,
    -- Costo mensual vigente: sueldo total integrado si es activo y > 0;
    -- nulo si es activo con sueldo 0 (dato faltante); 0 si es baja.
    costo_mensual,
    CASE
        WHEN es_activo = 'True' AND sueldo_total_integrado > 0 THEN sueldo_total_integrado
        WHEN es_activo = 'True' THEN NULL
        ELSE 0
    END AS costo_mensual_sql,
    -- Costo por hora = costo mensual / 160
    costo_hora,
    CASE WHEN es_activo = 'True' AND sueldo_total_integrado > 0
         THEN ROUND(sueldo_total_integrado / 160.0, 2) END AS costo_hora_sql,
    -- Documentos básicos entregados (de 7) y expediente completo
    docs_basicos_ok,
    (doc_acta = 'SI') + (doc_ine = 'SI') + (doc_curp = 'SI') + (doc_const_fiscal = 'SI')
      + (doc_nss = 'SI') + (doc_comprobante_domicilio = 'SI') + (doc_banco = 'SI') AS docs_basicos_ok_sql,
    -- Banca: activo sin ninguna asignación En Curso
    en_banca,
    CASE WHEN es_activo = 'True' AND n_asignaciones = 0 THEN 'True' ELSE 'False' END AS en_banca_sql
FROM colaboradores_acondicionada;

-- ---------------------------------------------------------------------
-- 2. Atributos de asignaciones
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_asignaciones_atributos;
CREATE VIEW v_asignaciones_atributos AS
SELECT
    a.id_asignacion,
    a.id_colaborador,
    a.id_proyecto,
    -- Fecha fin efectiva (regla R08): la del proyecto manda si la asignación
    -- termina después que el proyecto o si no tiene fecha de fin.
    a.fecha_fin_efectiva,
    CASE
        WHEN a.fecha_fin_registrada = '' THEN NULLIF(p.fecha_fin, '')
        WHEN p.fecha_fin <> '' AND a.fecha_fin_registrada > p.fecha_fin THEN p.fecha_fin
        ELSE a.fecha_fin_registrada
    END AS fecha_fin_efectiva_sql,
    -- Días para que termine = fecha fin efectiva − fecha de corte
    a.dias_para_fin,
    CAST(julianday(NULLIF(a.fecha_fin_efectiva, '')) - julianday('2026-11-17') AS INTEGER) AS dias_para_fin_sql,
    -- Estado de vigencia por rangos de días para fin
    a.estado_vigencia,
    CASE
        WHEN a.fecha_fin_efectiva = '' THEN 'INDEFINIDA / SIN FECHA FIN'
        WHEN julianday(a.fecha_fin_efectiva) < julianday('2026-11-17') THEN 'VENCIDA'
        WHEN julianday(a.fecha_fin_efectiva) - julianday('2026-11-17') <= 30 THEN '0-30 DÍAS'
        WHEN julianday(a.fecha_fin_efectiva) - julianday('2026-11-17') <= 60 THEN '31-60 DÍAS'
        WHEN julianday(a.fecha_fin_efectiva) - julianday('2026-11-17') <= 90 THEN '61-90 DÍAS'
        ELSE 'MÁS DE 90 DÍAS'
    END AS estado_vigencia_sql,
    -- % de dedicación = 1 / número de asignaciones En Curso de la persona (R06)
    a.pct_dedicacion,
    1.0 / (SELECT COUNT(*) FROM asignaciones_acondicionada x
           WHERE x.id_colaborador = a.id_colaborador AND x.estatus_asignacion = 'EN CURSO') AS pct_dedicacion_sql,
    -- Costo mensual asignado = costo mensual de la persona × % de dedicación
    a.costo_mensual_asignado,
    a.costo_mensual_persona * a.pct_dedicacion AS costo_mensual_asignado_sql
FROM asignaciones_acondicionada a
LEFT JOIN proyectos_acondicionada p ON p.id_proyecto = a.id_proyecto;

-- ---------------------------------------------------------------------
-- 3. Atributos de equipos (activos)
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_activos_atributos;
CREATE VIEW v_activos_atributos AS
SELECT
    q.cod_activo,
    -- Equipo por recuperar: vigente (sin fecha fin) y a nombre de una baja
    q.equipo_por_recuperar,
    CASE WHEN q.equipo_vigente = 'True' AND c.estatus_corte = 'BAJA' THEN 'True' ELSE 'False' END AS equipo_por_recuperar_sql,
    -- Valor por recuperar: costo del equipo sólo si se conoce (costo 0 = desconocido)
    q.valor_por_recuperar,
    CASE WHEN q.equipo_vigente = 'True' AND c.estatus_corte = 'BAJA' AND q.costo_origen > 0
         THEN q.costo_origen END AS valor_por_recuperar_sql
FROM activos_acondicionada q
LEFT JOIN colaboradores_acondicionada c ON c.id_colaborador = q.id_responsable;

-- ---------------------------------------------------------------------
-- 4. Indicadores (respuestas a las preguntas de análisis)
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_indicadores;
CREATE VIEW v_indicadores AS
SELECT 'P1' AS pregunta, 'Activos al corte' AS indicador,
       CAST(COUNT(*) AS TEXT) AS valor
  FROM colaboradores_acondicionada WHERE es_activo = 'True'
UNION ALL
SELECT 'P1', 'Tasa de utilización (activos con asignación / activos)',
       printf('%d de %d (%.1f%%)', SUM(tiene_asignacion = 'True'), COUNT(*),
              100.0 * SUM(tiene_asignacion = 'True') / COUNT(*))
  FROM colaboradores_acondicionada WHERE es_activo = 'True'
UNION ALL
SELECT 'P2', 'Asignaciones vencidas al corte',
       CAST(COUNT(*) AS TEXT)
  FROM asignaciones_acondicionada WHERE estado_vigencia = 'VENCIDA'
UNION ALL
SELECT 'P3', 'Proyectos En Curso sin personal',
       printf('%d de %d', SUM(sin_personal = 'True'), COUNT(*))
  FROM proyectos_acondicionada WHERE estatus_proyecto = 'EN CURSO'
UNION ALL
SELECT 'P4', 'Costo por hora promedio (activos con sueldo)',
       printf('$%.1f', AVG(costo_hora))
  FROM colaboradores_acondicionada WHERE es_activo = 'True' AND costo_hora <> ''
UNION ALL
SELECT 'P5', 'Costo mensual de la plantilla asignada',
       printf('$%,d', CAST(ROUND(SUM(costo_mensual_asignado)) AS INTEGER))
  FROM asignaciones_acondicionada WHERE costo_mensual_asignado <> ''
UNION ALL
SELECT 'P6', 'Costo mensual de la banca',
       printf('$%,d', CAST(ROUND(SUM(costo_mensual_banca)) AS INTEGER))
  FROM colaboradores_acondicionada WHERE en_banca = 'True' AND costo_mensual_banca <> ''
UNION ALL
SELECT 'P6', 'Peso de la banca sobre la nómina activa',
       printf('%.1f%%', 100.0 * SUM(CASE WHEN en_banca = 'True' THEN costo_mensual ELSE 0 END)
                        / SUM(costo_mensual))
  FROM colaboradores_acondicionada WHERE es_activo = 'True' AND costo_mensual <> ''
UNION ALL
SELECT 'P7', 'Habilidades con menos de 2 activos en nivel Avanzado/Experto',
       CAST(SUM(n_nivel3plus_activos < 2) AS TEXT)
  FROM habilidades_cobertura
UNION ALL
SELECT 'P9', 'Bajas con fecha / sin fecha',
       printf('%d / %d', SUM(baja_sin_fecha = 'False'), SUM(baja_sin_fecha = 'True'))
  FROM colaboradores_acondicionada WHERE estatus_corte = 'BAJA'
UNION ALL
SELECT 'P10', 'Expedientes básicos completos (7 de 7)',
       printf('%d de %d', SUM(expediente_completo = 'True'), COUNT(*))
  FROM colaboradores_acondicionada WHERE es_activo = 'True'
UNION ALL
SELECT 'P11', 'Equipos por recuperar / valor conocido',
       printf('%d / $%,d', SUM(equipo_por_recuperar = 'True'),
              CAST(ROUND(SUM(CASE WHEN equipo_por_recuperar = 'True' AND valor_por_recuperar <> ''
                                  THEN valor_por_recuperar ELSE 0 END)) AS INTEGER))
  FROM activos_acondicionada;
