# Automatización de backups con SQL Server Agent

**Semana 2 · Día 4** · SQL Server

---

## 1. Objetivo

Automatizar la estrategia de backup diseñada en el Día 3 (RPO de 15 minutos) 
mediante tres jobs de SQL Server Agent: full, diferencial y log. Base de práctica: `LabAgent`, en modelo de recuperación Full.

---

## 2. Conceptos

SQL Server Agent es un servicio de Windows, independiente del motor de la base, que ejecuta tareas programadas. Trabaja con tres piezas:

| Pieza | Qué es | Ejemplo |
|---|---|---|
| **Job** | La tarea completa | "Backup de log cada 10 minutos" |
| **Step** | Cada acción dentro del job | Ejecutar el comando `BACKUP LOG` |
| **Schedule** | Cuándo se dispara | Todos los días, cada 10 minutos |

Requisitos: el servicio debe estar en ejecución (no está disponible en la edición Express). 
En el laboratorio se dejó con inicio Manual para no generar archivos de forma continua; 
en un servidor real se configura como **Automático**, porque si el Agent está apagado los jobs no corren y no aparece ningún error.

---

## 3. Preparación

Se creó la base `LabAgent` con modelo Full y un backup full inicial, que es el punto de partida de la cadena de logs. Sin ese full, el backup de log es rechazado.

```sql
CREATE DATABASE LabAgent;
ALTER DATABASE LabAgent SET RECOVERY FULL;
BACKUP DATABASE LabAgent
TO DISK = 'C:\Backup\LabAgent_FULL_inicial.bak'
WITH COMPRESSION, CHECKSUM;
```

---

## 4. Los tres jobs

| Job | Frecuencia | Horario |
|---|---|---|
| `LabAgent - Backup FULL semanal` | Semanal | Lunes 01:00 |
| `LabAgent - Backup DIFERENCIAL cada 2 hs` | Cada 2 horas | 00:00:00 a 23:59:59 |
| `LabAgent - Backup LOG cada 10 min` | Cada 10 minutos | 00:00:00 a 23:59:59 |

### Job de log

```sql
DECLARE @archivo NVARCHAR(260);
SET @archivo = 'C:\Backup\LabAgent_LOG_' + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss') + '.trn';

BACKUP LOG LabAgent
TO DISK = @archivo
WITH COMPRESSION, CHECKSUM;
```

### Job diferencial

```sql
DECLARE @archivo NVARCHAR(260);
SET @archivo = 'C:\Backup\LabAgent_DIFF_' + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss') + '.bak';

BACKUP DATABASE LabAgent
TO DISK = @archivo
WITH DIFFERENTIAL, COMPRESSION, CHECKSUM;
```

### Job full

```sql
DECLARE @archivo NVARCHAR(260);
SET @archivo = 'C:\Backup\LabAgent_FULL_' + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss') + '.bak';

BACKUP DATABASE LabAgent
TO DISK = @archivo
WITH COMPRESSION, CHECKSUM;
```

---

## 5. Decisiones de diseño

- **Nombre de archivo único con fecha y hora.** Si todos los backups de log se guardaran con el mismo nombre y se sobrescribieran,
  se perdería el tramo anterior y la cadena de logs quedaría con un hueco. Con la fecha y hora en el nombre, cada backup cae en su propio archivo.
  Se aplicó el mismo criterio al full y al diferencial: si un backup nuevo falla a mitad de camino, no se pierde la única copia,
  y se conserva la posibilidad de volver a un punto más antiguo.
- **Full a las 01:00 los lunes.** Los diferenciales corren en las horas pares (00:00, 02:00, 04:00...), por lo que el full no coincide con ninguno.
- Los backups de log pueden ejecutarse mientras corre un full.
- **`COMPRESSION` y `CHECKSUM` en los tres jobs.** La compresión reduce el tiempo de restauración (RTO) y
- el checksum verifica la integridad de las páginas al respaldarlas.

---

## 6. Pruebas y resultados

- Cada job se probó manualmente con **Start Job at Step...** antes de dejarlo con su horario. Los tres terminaron en **Success**.
- Con el horario activo, el job de log corrió solo cada 10 minutos durante la tarde, con todas las ejecuciones exitosas en el historial (**View History**).
- El archivo del backup diferencial pesó **menos** que el del full: guarda únicamente los cambios desde el último full, y en `LabAgent` casi no hubo cambios.
- En el historial se observó **una ejecución faltante** (la de las 17:00). Probablemente se debió a una suspensión del equipo.
  En un servidor real un hueco así dejaría un tramo sin respaldo y pondría en riesgo el RPO, por lo que requeriría una alerta.

---

## 8. Limitaciones y mejoras pendientes

- **Retención:** no hay una política de limpieza. Los archivos se acumulan.
  En producción se agrega un job de limpieza que borre solo los backups más antiguos que el full más viejo que se quiere poder restaurar,
  nunca un log del medio de la cadena.
- **Destino:** en el laboratorio los backups van a `C:\Backup`, el mismo equipo que la base. En producción deben ir a otro disco o servidor,
  para sobrevivir a una falla del disco principal.
- **Monitoreo:** si un job falla, nadie se entera. El siguiente paso es configurar Database Mail y alertas de falla de jobs.
- **Prueba de restauración:** falta restaurar `LabAgent` a partir de la cadena generada por los jobs, para comprobar que funciona de punta a punta.
