# Avance Reto Etapa 3: Tratamiento y Acondicionamiento de Datos

**OT Consulting** · Soporte analítico para la toma de decisiones · Grupo 301
**Diego Perez Sánchez** · A01236912 · Fecha de corte de los datos: 17 de noviembre de 2026

| Archivo | Contenido |
| --- | --- |
| [diegoOT_Etapa3_Acondicionamiento.ipynb](diegoOT_Etapa3_Acondicionamiento.ipynb) | Notebook en Python (ejecutado): recuerda las inconsistencias de la Etapa 2, aplica los métodos de corrección M01 a M11, calcula los atributos nuevos, genera la bitácora de correcciones, las validaciones, la metadata y las gráficas. |
| [diegoOT_atributos.sql](diegoOT_atributos.sql) | Fórmulas de los atributos nuevos e indicadores escritas en SQL (SQLite) sobre las tablas acondicionadas. |
| [diegoOT_ejecutar_sql.py](diegoOT_ejecutar_sql.py) | Carga las tablas acondicionadas en SQLite, ejecuta el SQL y comprueba que cada atributo da lo mismo que en el notebook. Resultado en [salida/evidencia_sql.txt](salida/evidencia_sql.txt). |
| [diegoOT_datos_acondicionados.xlsx](diegoOT_datos_acondicionados.xlsx) | Tablas acondicionadas, metadata (meta_tablas y meta_columnas), bitácora, validaciones y resúmenes en un solo Excel. |
| [salida/](salida/) | Las mismas tablas en CSV, la bitácora de 37 correcciones, las 25 validaciones, la metadata y las gráficas de evidencia (`salida/img`). |

## Cómo correrlo

- **Notebook:** necesita los 10 archivos del ERP de OTC (`Catalogo_Colaboradores.xlsx`, `Asignaciones_Colaboradores.xlsx`, etc.) en la misma carpeta, o en la ruta de la variable `OTC_DATA`. En Colab los pide al iniciar. Las salidas ya quedan guardadas en el notebook.
- **SQL:** `python diegoOT_ejecutar_sql.py` (sólo requiere pandas; usa las tablas de `salida/`).

## Resultado principal

8 tablas acondicionadas, 37 correcciones registradas y 25 validaciones automáticas (24 pasan; la que falla es un hallazgo de los datos: los 6 PM de OTC no aparecen como colaboradores). Ningún dato faltante se inventa: queda en nulo con una bandera que explica por qué.
