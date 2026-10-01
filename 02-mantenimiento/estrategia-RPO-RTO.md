# Estrategia de backup según RPO y RTO

**Semana 2 · Día 3** · SQL Server

---

## 1. Escenario

Tienda online con una base de datos de pedidos. *(Los tiempos son supuestos inventados para practicar.)*

| Dato | Valor |
|---|---|
| **RPO exigido** | 15 minutos |
| **RTO exigido (inicial)** | 1 hora |
| **RTO exigido (endurecido)** | 45 minutos |
| Restaurar el full | 30 min (20 min con compresión y disco rápido) |
| Restaurar el último diferencial | 10 min |
| Aplicar cada log | 1 min |

---

## 2. Conceptos clave

**RPO:** Recovery Point Objective. Hasta qué punto puedo volver si sucede algún desastre; en otras palabras, cuánto tiempo puedo permitirme perder en datos. Lo decide la **frecuencia del backup de log**.

**RTO:** Recovery Time Objective. Cuánto tiempo puedo estar sin sistema mientras se hace la restauración. Lo decide el **tiempo que tarda la restauración** (full + último diferencial + logs).

Los números los define el negocio; el DBA los traduce en una estrategia de backups.

---

## 3. Diseño elegido

**Modelo de recuperación:** Full (requisito para hacer backups de log y volver a un momento exacto).

| Pieza | Frecuencia | Por qué |
|---|---|---|
| Backup **full** | Semanal (lunes) | Es el punto de partida de toda la cadena de restauración. |
| Backup **diferencial** | Cada 2 horas | Reemplaza a muchos logs viejos: al restaurar solo hay que aplicar los logs posteriores al último diferencial, lo que acorta el RTO. |
| Backup de **log** | Cada 10 minutos | Cumple el RPO de 15 minutos y deja 5 minutos de margen. |

**Opciones de los backups:** `COMPRESSION` y `CHECKSUM`.

**Destino:** disco o servidor distinto al de la base. 
Si los backups estuvieran en el mismo disco, una falla de ese disco se llevaría la base y sus backups juntos.

---

## 4. Cálculo del RPO

**Peor caso:** con este diseño, en el peor de los casos se perderán 10 minutos de información.

**Margen:** 5 minutos respecto al objetivo de 15.

Esto solo se cumple si los backups de log sobreviven al desastre. 
Si estuvieran en el mismo disco que la base, una falla de disco los destruiría junto con ella, 
y la pérdida real sería la antigüedad del último backup guardado en otro lugar, mucho mayor que 10 minutos.

---

## 5. Cálculo del RTO

El peor caso es que el desastre ocurra justo antes del próximo diferencial. 
Hay que restaurar: **full + último diferencial + todos los logs posteriores a ese diferencial**.

| Versión del diseño | Full | Diferencial | Logs | Total | ¿Cumple 45 min? |
|---|---|---|---|---|---|
| v1: diferencial cada 4 h, log cada 15 min | 30 | 10 | 16 x 1 = 16 | **56 min** | No |
| v2: diferencial cada 2 h, log cada 10 min | 30 | 10 | 12 x 1 = 12 | **52 min** | No |
| v3: v2 + compresión y disco rápido | 20 | 10 | 12 x 1 = 12 | **42 min** | Sí |

- **La fila que más pesaba:** el restore del full (30 de los 52 minutos de v2).
- **Palanca más eficaz:** comprimir los backups y restaurar desde un disco más rápido, porque atacó directamente la pieza más pesada (el full bajó de 30 a 20 minutos).
- **Palanca menos eficaz:** hacer diferenciales o fulls más seguidos. Los diferenciales más frecuentes solo reducen la cantidad de logs a aplicar, y un full más frecuente no hace más rápido el restore del full. Además, subir la frecuencia de los logs mejora el RPO pero agrega logs a la cadena, lo que empeora el RTO.

---

## 6. Decisiones y justificación

- **Log cada 10 minutos y no cada 15:** con 15 el peor caso es exactamente el RPO, sin margen. Con 10 queda un colchón de 5 minutos por si un backup tarda o falla.
- **Diferenciales en lugar de solo full + logs:** sin diferenciales habría que aplicar los logs de toda la semana. Con ellos, solo los de las últimas 2 horas como máximo.
- **Compresión y disco más rápido para el restore:** el RTO está dominado por el restore del full, así que es la mejora con más impacto.

---

## 7. Riesgos y limitaciones

- El margen del diseño final es de solo **3 minutos** (42 contra 45).
- Los tiempos son **supuestos**: en un entorno real hay que **medirlos** haciendo restores de prueba.
- Para validar que el diseño cumple el RTO, programaría restores de prueba periódicos en otro servidor, cronometraría cada etapa y verificaría los backups con `RESTORE VERIFYONLY` y `CHECKSUM`.
- Si falla un backup de log intermedio, **la cadena se corta**: solo se podría restaurar hasta el último log anterior al faltante. Habría que tomar cuanto antes un nuevo diferencial (o full) para volver a tener cobertura completa.


