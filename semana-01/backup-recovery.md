# Backup y Recuperación en SQL Server

## Escenario

Se simulo un desastre completo sobre una base de datos de laboratorio, con el objetivo de practicar el ciclo completo de backup y restauración, incluyendo 
recuperación a un punto exacto en el tiempo (point-in-time recovery).

## Modelo de recuperación

La base se configuro en modelo **Full**, requisito indispensable para poder hacer backups de log y restaurar a un punto exacto.

## backups realizados

- crear una base en modelo simple
 CREATE DATABASE LabRecovery; 
 ALTER DATABASE LabRecovery SET RECOVERY SIMPLE; 
 
 USE LabRecovery; 
 
 CREATE TABLE Registros (ID INT IDENTITY PRIMARY KEY, Dato VARCHAR(100)); 
 INSERT INTO Registros (Dato) VALUES ('primer dato');
 INSERT INTO Registros (Dato) VALUES ('dato2'),('dato3'),('dato4'),('dato5'),('dato6'),('dato7'),('dato8'),('dato9'),('dato10'),('dato11');

 -- intentar hacer un backup del log
 BACKUP LOG LabRecovery TO DISK = 'C:\Backup\LabRecovery_log.trn'

 -- cambiar a full y hacer backup full inicial
 ALTER DATABASE LabRecovery SET RECOVERY FULL; 
 BACKUP DATABASE LabRecovery TO DISK = 'C:\Backup\LabRecovery_full.bak';

 -- backup full es obligatorio, arranca la cadena de logs!
INSERT INTO Registros (Dato) VALUES ('dato despues del full'); 
 
 -- primer log captura lo que paso del full hasta ahora, comienza la cadena de logs
 BACKUP LOG LabRecovery TO DISK = 'C:\Backup\LabRecovery_log1.trn'; 
 
 INSERT INTO Registros (Dato) VALUES ('dato critico a recuperar'); 
 
 -- guardar fecha y hora en una variable
 DECLARE @momento DATETIME = GETDATE(); 
 -- pausa ejecucion 5 seg
 WAITFOR DELAY '00:00:05'; 
 
 -- simulacion de error
 INSERT INTO Registros (Dato) VALUES ('dato que voy a perder a proposito'); 
 
 -- segundo log
 BACKUP LOG LabRecovery TO DISK = 'C:\Backup\LabRecovery_log2.trn';

 SELECT @momento; 
 -- anotar para manana

BACKUP DATABASE LabRecovery TO DISK = 'C:\Backup\LabRecovery_diff.bak'
WITH DIFFERENTIAL, COMPRESSION, CHECKSUM;

## El desastre simulado

use master

-- simular desastre, la base se pierde por completo
/* SINGLE_USER WITH ROLLBACK IMMEDIATE corta cualquier conexión activa para poder borrarla sin que nada lo impida.*/
alter database LabRecovery set single_user with rollback immediate;
drop database LabRecovery;

## la recuperacion

-- capturar todo lo que hay en el momento antes de empezar a restaurar
/*
— incluidas las transacciones buenas que pasaron después del error. Así no perdés ese tramo por completo, queda guardado en un archivo aparte.
*/
BACKUP LOG LabRecovery TO DISK = 'C:\Backup\tail_log.trn' WITH NORECOVERY;

-- restaurar backup full sin cerrar
-- NORECOVERY le dice a SQL Server todavía faltan más archivos por aplicar, no cierres la restauración

restore database LabRecovery from disk ='C:\Backup\LabRecovery_full.bak' with norecovery;

-- aplicar primer log con datos buenos
restore log LabRecovery from disk = 'C:\Backup\LabRecovery_log1.trn' with norecovery;

-- STOPAT aplica el log solo hasta ese instante exacto.
restore log LabRecovery from disk = 'C:\Backup\LabRecovery_log2.trn' 
with stopat = '2026-09-24 07:34:35.527',recovery;

USE LabRecovery; SELECT * FROM Registros ORDER BY ID; 

## Resultado

El dato "dato critico a recuperar" se recupero correctamente. El dato "dato que voy a perder a proposito", insertado despues del punto de corte, no aparece en la base 
restaurada — tal como se esperaba.

## Limitaciones y mejoras a futuro

**STOPAT** descarta **todo** lo que ocurrio despues del punto de corte, sin distinguir entre transacciones buenas y malas. En un escenario real, donde suele haber actividad 
valida despues del incidente y antes de que se detecte, esto generaria perdida de datos buenos.

La solucion real usada en produccion es el **tail-log backup**: respaldar el log justo antes de empezar la restauracion, para no perder la actividad posterior al 
desastre. Ese tramo se restaura aparte, se identifican manualmente las transacciones validas, y se vuelven a aplicar sobre la base ya recuperada.

Este escenario mas avanzado (tail-log backup + rescate manual de transacciones) se va a practicar en la Semana 2, durante el simulacro de corrupcion.


RESTORE VERIFYONLY FROM DISK = 'C:\Backup\LabRecovery_diff.bak';
