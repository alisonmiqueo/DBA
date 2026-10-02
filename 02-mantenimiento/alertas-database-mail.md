# Alertas y notificaciones con Database Mail

**Semana 2 · Día 5** · SQL Server

---

## 1. Objetivo

Hacer que SQL Server avise cuando un job de backup falla o cuando detecta errores de corrupción, en lugar de depender de revisar el historial a mano. 
La motivación viene del Día 4: en el historial del job de log apareció una ejecución faltante (la de las 17:00) que nadie notó en el momento.

---

## 2. Las piezas

| Pieza | Qué es | Analogía |
|---|---|---|
| **Database Mail** | Mecanismo que permite a SQL Server enviar correos | El cartero |
| **Perfil** | Paquete de configuración de correo que usa el Agent | La oficina de correos asignada |
| **Operador** | Contacto con nombre y dirección de correo | El destinatario |
| **Notificación de job** | Aviso ligado al resultado de un job puntual | "Si este backup falla, avisá" |
| **Alerta** | Regla ligada a un evento del servidor, como un número de error | "Si ocurre el error 824, avisá" |

---

## 3. Configuración realizada

### 3.1 Database Mail

Se creó el perfil `PerfilLab` con una cuenta de envío ficticia, ya que el laboratorio no usa cuentas reales.

| Campo | Valor |
|---|---|
| Account name | CuentaFicticia |
| E-mail address | alertas-lab@example.com |
| Display name | SQL Server Lab |
| Server name | smtp.example.com |
| Port | 587 |
| Conexión segura (SSL) | No |
| Autenticación | Anónima |

En un servidor real solo cambiarían el servidor SMTP, la conexión segura (siempre activada) y la autenticación (usuario y contraseña de aplicación).

### 3.2 Operador

Se creó el operador `DBA_Lab` con la dirección `dba-lab@example.com`.

### 3.3 Conexión del Agent con Database Mail

En las propiedades de SQL Server Agent, pestaña *Alert System*, se activó el perfil de correo y se eligió `PerfilLab`. 
El Agent solo lee esta configuración al arrancar, por lo que hubo que **reiniciarlo**.

### 3.4 Notificación de falla en los jobs de backup

En los tres jobs (full, diferencial y log) se activó la notificación por correo a `DBA_Lab` con la opción **When the job fails**.

### 3.5 Alertas de corrupción

Se crearon tres alertas para todas las bases de datos, con aviso por correo al operador e incluyendo el texto del error:

| Error | Significado |
|---|---|
| **823** | Falla de lectura reportada por el sistema operativo |
| **824** | El checksum de una página no coincide (corrupción lógica de I/O) |
| **825** | Una lectura falló pero se reintentó con éxito (alerta temprana) |

---

## 4. Prueba

Se creó un job de prueba, `PRUEBA - Falla a propósito`, con un único paso que ejecuta `SELECT 1/0;` para forzar un error, y se ejecutó manualmente. 
Después se revisó:

```sql
-- Cola de mensajes de Database Mail
SELECT TOP 5 mailitem_id, recipients, subject, sent_status, send_request_date
FROM msdb.dbo.sysmail_allitems
ORDER BY mailitem_id DESC;

-- Registro de eventos de Database Mail
SELECT TOP 5 log_date, event_type, description
FROM msdb.dbo.sysmail_event_log
ORDER BY log_id DESC;
```

**Resultados:**
- El job figuró como **fallido** en el historial, con el mensaje de división por cero.
- El Agent generó el aviso y Database Mail lo puso en cola.
- El envío **falló**, como se esperaba, porque `smtp.example.com` no existe. El motivo quedó registrado en `sysmail_event_log`.

**Conclusión:** el circuito Agent, Database Mail y operador funciona de punta a punta. 
Lo único que no se pudo verificar es la entrega real a una bandeja de entrada. El job de prueba se eliminó al terminar.

---

## 5. Por qué alertar también el error 825

Aunque no es un error grave (la lectura se reintentó y funcionó), indica que el almacenamiento está empezando a fallar. 
Avisa **antes** de que aparezcan los errores 823 y 824, que ya implican daño real, y deja tiempo para revisar el hardware, 
hacer un backup y correr `DBCC CHECKDB`.

---

## 6. Decisiones de diseño

- **Notificar solo cuando el job falla**, no cuando termina bien. Si cada ejecución exitosa enviara un correo,
- el log de 10 minutos generaría cientos de mensajes por día y terminarían ignorándose todos (fatiga de alertas).
- **Alertas para todas las bases** (`<all databases>`), porque la corrupción puede aparecer en cualquiera.
- **Verificar con un job que falla a propósito**: una alerta que nunca se probó no se puede considerar confiable.
- **Revisar `sysmail_event_log` primero** cuando un aviso no llega: indica el motivo del fallo del envío.

---

## 7. Limitaciones y mejoras pendientes

- **Entrega no verificada:** el servidor SMTP es ficticio. Falta probarlo con uno real.
- **Alertas 823, 824 y 825 sin probar:** solo se probó la notificación de job. Probarlas requiere provocar corrupción real,
- por ejemplo repitiendo el laboratorio sobre `LabCorrupcion`.
- **Sin alertas por severidad:** la práctica habitual también incluye alertas para los errores de severidad 19 a 25 (errores graves del servidor).
- **Un único operador:** en producción se usa una lista de distribución o un esquema de guardias, para que el aviso llegue siempre a alguien.
- **Agent en inicio Manual:** correcto para el laboratorio. En producción debe ser **Automático**,
- porque con el Agent apagado ni los jobs ni las alertas funcionan, y no aparece ningún error.
