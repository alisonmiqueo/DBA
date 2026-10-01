# Semana 2 · Mantenimiento y recuperación avanzada

## Día 1  · DBCC CHECKDB

## ¿Qué es DBCC CHECKDB?

DBCC CHECKDB es el comando que usa un DBA para revisar la integridad de una base de datos: recorre todas las tablas, índices y el catálogo del sistema para detectar corrupción física o lógica. No repara nada por sí solo salvo que se le indique explícitamente con una opción de reparación. Es la base de cualquier rutina de mantenimiento, porque un backup puede guardar corrupción sin avisar — solo CHECKDB confirma que los datos están sanos.

- Configuración verificada

SELECT name, page_verify_option_desc, state_desc
FROM sys.databases
WHERE name = 'AdventureWorks2022';

- Resultado:
AdventureWorks2022	CHECKSUM	ONLINE

- Comandos ejecutados

1. CHECKDB con NO_INFOMSGS (silencioso si todo está bien)

DBCC CHECKDB (AdventureWorks2022) WITH NO_INFOMSGS;


2. CHECKDB completo, con mensajes informativos

DBCC CHECKDB (AdventureWorks2022);

3. CHECKDB con PHYSICAL_ONLY (chequeo liviano)

DBCC CHECKDB (AdventureWorks2022) WITH PHYSICAL_ONLY, NO_INFOMSGS;

4. Páginas sospechosas registradas históricamente

SELECT * FROM msdb.dbo.suspect_pages;

Resultado: 0 filas — sin páginas dañadas en el historial.

Hallazgos
La base AdventureWorks2022 está sana: 0 errores de asignación, 0 errores de consistencia.
