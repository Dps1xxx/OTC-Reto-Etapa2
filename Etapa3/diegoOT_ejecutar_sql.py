"""
OT Consulting · Avance Reto Etapa 3 · Diego Perez Sánchez (A01236912)

Carga las tablas acondicionadas (salida/*.csv) en una base SQLite en memoria,
ejecuta diegoOT_atributos.sql y comprueba que cada atributo recalculado en SQL
coincide con el que calculó el notebook en Python. Al final imprime los indicadores.

Uso:  python diegoOT_ejecutar_sql.py
"""
import os
import sqlite3
import pandas as pd

BASE = os.path.dirname(os.path.abspath(__file__))
SALIDA = os.path.join(BASE, 'salida')
TABLAS = ['colaboradores_acondicionada', 'asignaciones_acondicionada', 'proyectos_acondicionada',
          'activos_acondicionada', 'habilidades_cobertura']


def cargar(nombre):
    """Lee el CSV como texto; las columnas 100% numéricas pasan a número y su vacío a NULL."""
    df = pd.read_csv(os.path.join(SALIDA, f'{nombre}.csv'), dtype=str, keep_default_na=False, encoding='utf-8-sig')
    for col in df.columns:
        llenos = df[col][df[col] != '']
        if len(llenos) and pd.to_numeric(llenos, errors='coerce').notna().all():
            df[col] = pd.to_numeric(df[col].replace('', None))
    return df


con = sqlite3.connect(':memory:')
for t in TABLAS:
    cargar(t).to_sql(t, con, index=False)
with open(os.path.join(BASE, 'diegoOT_atributos.sql'), encoding='utf-8') as f:
    con.executescript(f.read())

# Pares (vista, columna del notebook, columna recalculada en SQL)
PARES = [
    ('v_colaboradores_atributos', 'estatus_corte', 'estatus_corte_sql'),
    ('v_colaboradores_atributos', 'antiguedad_anios', 'antiguedad_anios_sql'),
    ('v_colaboradores_atributos', 'costo_mensual', 'costo_mensual_sql'),
    ('v_colaboradores_atributos', 'costo_hora', 'costo_hora_sql'),
    ('v_colaboradores_atributos', 'docs_basicos_ok', 'docs_basicos_ok_sql'),
    ('v_colaboradores_atributos', 'en_banca', 'en_banca_sql'),
    ('v_asignaciones_atributos', 'fecha_fin_efectiva', 'fecha_fin_efectiva_sql'),
    ('v_asignaciones_atributos', 'dias_para_fin', 'dias_para_fin_sql'),
    ('v_asignaciones_atributos', 'estado_vigencia', 'estado_vigencia_sql'),
    ('v_asignaciones_atributos', 'pct_dedicacion', 'pct_dedicacion_sql'),
    ('v_asignaciones_atributos', 'costo_mensual_asignado', 'costo_mensual_asignado_sql'),
    ('v_activos_atributos', 'equipo_por_recuperar', 'equipo_por_recuperar_sql'),
    ('v_activos_atributos', 'valor_por_recuperar', 'valor_por_recuperar_sql'),
]


def igual(a, b):
    vacio_a = a is None or a == '' or (isinstance(a, float) and pd.isna(a))
    vacio_b = b is None or b == '' or (isinstance(b, float) and pd.isna(b))
    if vacio_a or vacio_b:
        return vacio_a and vacio_b
    try:
        return abs(float(a) - float(b)) < 0.01
    except (TypeError, ValueError):
        return str(a) == str(b)


print('Comprobación Python (notebook) vs SQL')
print('-' * 72)
total_dif = 0
for vista, col_py, col_sql in PARES:
    df = pd.read_sql(f'SELECT {col_py} AS py, {col_sql} AS sq FROM {vista}', con)
    dif = int((~df.apply(lambda r: igual(r.py, r.sq), axis=1)).sum())
    total_dif += dif
    print(f'{"OK   " if dif == 0 else "FALLA"} {vista:28s} {col_py:24s} {len(df) - dif}/{len(df)} filas iguales')
print('-' * 72)
print('Todas las fórmulas SQL coinciden con el notebook.' if total_dif == 0 else f'{total_dif} diferencias.')

print('\nIndicadores calculados en SQL')
print(pd.read_sql('SELECT * FROM v_indicadores', con).to_string(index=False))
