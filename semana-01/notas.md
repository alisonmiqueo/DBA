# Semana 1 — Fundamentos y primer backup/restore

## Dia 1 — 22/09
- Verifiqué mi instalación: SQL Server 2022 Developer Edition
- Restauré AdventureWorks2022
- Consultas SQL con múltiples JOINS, WHERE,HAVING,GROUP BY,subconsultas, CTEs y funciones de ventana.

# Dia 2 - 23/09
-¿Por qué tempdb puede terminar más grande después de correr una consulta pesada, aunque hayas borrado la tabla temporal al final?

 La idea central la tenés perfecta: tempdb no se achica sola, hace falta reiniciar el servicio para que vuelva a su tamaño original. Solo un matiz en la palabra "se actualiza" — no es que se actualice al reiniciar, es más bien que se recrea desde cero cada vez que el servicio de SQL Server arranca (por eso en la teoría te dije que "se recrea desde cero cada vez que reinicia"). Mientras el servicio sigue corriendo, tempdb puede crecer con el uso pero nunca se reduce sola — necesita ese reinicio completo para "resetearse". Es un dato real que vas a usar como DBA: si tempdb crece descontroladamente y empieza a ocupar mucho disco, muchas veces la solución es coordinar un reinicio del servicio (fuera de horario, claro).
 
-¿Qué relación hay entre la base model y cualquier base nueva que crees?

Perfecta, y me gustó mucho la analogía de clase-instancia — es exactamente esa lógica: model es la "clase" (la definición, la plantilla) y cada base nueva que creás es una "instancia" que nace con esas mismas características por defecto (recovery model, collation, etc.), pero después puede evolucionar de forma independiente.
