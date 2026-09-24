use AdventureWorks2022

-- ¿Cuáles son los 10 productos más vendidos por cantidad?

select top 10 
pro.Name as producto,
sub.Name as categoria,
sum(det.OrderQty) as cantidad_vendida
from Production.Product as pro
inner join Production.ProductSubcategory as sub
on pro.ProductSubcategoryID = sub.ProductSubcategoryID
inner join Sales.SalesOrderDetail as det
on pro.ProductID = det.ProductID
group by pro.Name, sub.Name
order by cantidad_vendida

-- que clientes hicieron mas de 5 pedidos?

select top 5 
person.FirstName, 
person.LastName,
count(sales.SalesOrderID) as cantidad_pedidos
from Sales.SalesOrderHeader as sales
inner join Sales.Customer as customer
on sales.CustomerID = customer.CustomerID
inner join Person.Person as person
on customer.PersonID = person.BusinessEntityID
GROUP BY person.FirstName, person.LastName
HAVING COUNT(sales.SalesOrderID) > 5
order by cantidad_pedidos desc

/*
WHERE nunca puede filtrar por el resultado de un COUNT.
Para filtrar por el resultado de una función de agregación (COUNT, SUM, AVG), se usa HAVING, que corre después del GROUP BY.
*/

-- ¿Qué productos tienen un precio de lista por encima del promedio general?

select p.Name, p.ListPrice
from Production.Product as p
where p.ListPrice > ( select AVG(ListPrice) from Production.Product
where ListPrice > 0)
order by ListPrice desc

/*
Una CTE (WITH ... AS) es básicamente una subconsulta con nombre, que definís antes de la consulta principal, 
para hacerla más legible cuando la lógica se complica
*/

-- ¿cuál es el total de ventas (SubTotal) por territorio, y qué porcentaje representa cada territorio sobre el total general?

WITH VentasPorTerritorio AS (
    SELECT territory.Name as territorio,
	sum(sales.SubTotal) as total_ventas
	from Sales.SalesTerritory as territory
	inner join Sales.SalesOrderHeader as sales
	on territory.TerritoryID = sales.TerritoryID
	group by territory.Name
)
SELECT territorio, total_ventas,
sum(total_ventas) over() as total_general,
cast(total_ventas * 100.0 / sum(total_ventas) over () as decimal(5,2)) as porcentaje
FROM VentasPorTerritorio
order by total_ventas desc
-- cast redondea el resultado a 2 decimales
-- over () funcion de ventana

/*
Rankeá a los clientes según el total gastado, de mayor a menor, usando RANK() OVER (ORDER BY ... DESC). Tablas: SalesOrderHeader + Customer + Person.
*/

with total_gastado as(
select Person.FirstName as nombre ,
Person.LastName as apellido,
sum(sales.SubTotal)  as total
from Sales.SalesOrderHeader as sales
inner join Sales.Customer as costumer
on sales.CustomerID = costumer.CustomerID
inner join Person.Person on Person.BusinessEntityID = costumer.PersonID
group by Person.FirstName, Person.LastName -- no se usan alias en group by
)
select nombre, apellido,total,
RANK() OVER (ORDER BY total DESC) AS posicion
from total_gastado

/*
¿Qué vendedor (Sales.SalesPerson) tiene más órdenes asignadas? Contá SalesOrderHeader agrupando por SalesPersonID, y traé el nombre desde Person.Person.
*/

with ordenes_vendedor as (
select 
sap.BusinessEntityID,
Person.FirstName as nombre, 
Person.LastName as apellido,
count(sales.SalesOrderID) as total_ordenes
from Sales.SalesPerson as sap
inner join Sales.SalesOrderHeader as sales
on sales.SalesPersonID = sap.BusinessEntityID
inner join Person.Person 
on Person.BusinessEntityID = sap.BusinessEntityID
group by sap.BusinessEntityID, Person.FirstName, Person.LastName
)
select nombre,apellido,total_ordenes
from ordenes_vendedor
order by total_ordenes desc 


/*
Sumá SubTotal agrupando por año de OrderDate. Pista: YEAR(OrderDate) te da el año como número, y lo podés usar directo en el GROUP BY.
*/
select 
year(sales.OrderDate)as anio,
sum(sales.SubTotal) as total_ventas
from Sales.SalesOrderHeader as sales
group by year(sales.OrderDate)
order by anio

/*
Productos de Production.Product cuyo ProductID no aparece en ningún Sales.SalesOrderDetail
*/

select p.ProductID,
p.Name as producto
from Production.Product as p
where p.ProductID not in (select sales.ProductID from Sales.SalesOrderDetail as sales)

select p.ProductID,
    p.Name as producto
from Production.Product as p
where not exists (
    select 1 
    from Sales.SalesOrderDetail as sod 
    where sod.ProductID = p.ProductID
)

/*
Con DATEDIFF(day, OrderDate, ShipDate), calculá el promedio de días que tarda un envío, agrupado por territorio.
*/
select terr.Name as territorio,
AVG(DATEDIFF(day, sales.OrderDate, sales.ShipDate)) AS promedio_dias_envio
from Sales.SalesOrderHeader as sales
inner join Sales.SalesTerritory as terr
on sales.TerritoryID = terr.TerritoryID
group by terr.Name
ORDER BY promedio_dias_envio DESC;

/*
El desafío más grande: dentro de cada territorio, rankear a los clientes por gasto y quedarte solo con el top 3 de cada uno. 
Necesitás ROW_NUMBER() OVER (PARTITION BY TerritoryID ORDER BY SUM(...) DESC) dentro de una CTE, y después filtrar por ese número en la consulta de afuera.
*/

with gastos_clientes as (
select 
terr.Name as territorio,
person.FirstName as nombre,
person.LastName as apellido,
sum(sales.SubTotal) as total
from Sales.Customer as costumer
inner join Sales.SalesOrderHeader as sales
on sales.CustomerID = costumer.CustomerID
inner join Person.Person as person
on person.BusinessEntityID = costumer.PersonID
inner join Sales.SalesTerritory as terr
on sales.TerritoryID = terr.TerritoryID
group by terr.Name, person.FirstName,person.LastName
),
ranking AS (
    SELECT 
        territorio, nombre, apellido, total,
        ROW_NUMBER() OVER (PARTITION BY territorio ORDER BY total DESC) AS posicion
    FROM gastos_clientes
)
SELECT territorio, nombre, apellido, total, posicion
FROM ranking
WHERE posicion <= 3
ORDER BY territorio, posicion;

/*
Desafío integrador

Consigna: para cada categoría de producto (ProductSubcategory), 
mostrar solo los 2 productos con mayor precio de lista (ListPrice), 
pero excluyendo las categorías que tengan menos de 5 productos en total.

Esto te obliga a combinar, en una sola consulta:

GROUP BY + HAVING (para descartar categorías chicas)
Una CTE
PARTITION BY con ROW_NUMBER() (para el top 2 por categoría)
Cuidado con los alias, ya que vas a tener varias tablas
*/

use AdventureWorks2022

with categoria_producto as (
select p.ProductID as ID,
p.Name as producto, 
s.Name as categoria, 
p.ListPrice as precio,
COUNT(p.ProductID) OVER (PARTITION BY s.Name) as productos_en_categoria
from Production.Product as p
inner join Production.ProductSubcategory as s
on p.ProductSubcategoryID = s.ProductSubcategoryID
),
ranking AS (
select ID, producto,categoria, precio,
ROW_NUMBER() over(partition by categoria order by precio desc) as posicion
from categoria_producto
where productos_en_categoria > 5
)
SELECT ID, producto,categoria, precio, posicion
FROM ranking
WHERE posicion <= 2
ORDER BY categoria, posicion;

-- pracrica 3

/*
Ejercicio 1 — CASE WHEN (clasificación de datos)

Clasificá cada producto según su precio: "Económico" si ListPrice es menor a 50, 
"Medio" si está entre 50 y 500, y "Premium" si es mayor a 500. 
Mostrá Name, ListPrice y la categoría.

Pista mínima: se usa CASE WHEN ... THEN ... ELSE ... END como si fuera una columna más del SELECT.
*/

select 
p.ProductID,
p.Name as producto,
p.ListPrice as precio,
case 
when p.ListPrice = 0 then 'No disponible'
when p.ListPrice < 50 then 'Economico'
when p.ListPrice between 50 and 500 then 'Medio'
else 'Premium' END as categoria
from Production.Product as p


/*
Ejercicio 2 — Funciones de fecha

¿Cuántas órdenes de venta se hicieron por cada mes del año 2013? 
Mostrá el mes (como número o nombre) y la cantidad de órdenes, ordenado cronológicamente.
*/

select 
year(sales.OrderDate) as anio,
MONTH(sales.OrderDate) as mes,
COUNT(sales.SalesOrderID) as cantidad
from Sales.SalesOrderHeader as sales
where year(sales.OrderDate) = 2013
group by year(sales.OrderDate), MONTH(sales.OrderDate)
order by mes

/*
Ejercicio 3 — Self-join (tabla contra sí misma)

HumanResources.Employee no tiene jefe directo en esa tabla, 
pero Person.Person sí tiene una estructura de organización en otras tablas... en cambio, 
hay algo más simple: en Sales.SalesPerson, cada vendedor tiene un TerritoryID. 
Encontrá pares de vendedores que trabajen en el mismo territorio 
(sin que se repita el mismo par al revés, y sin que un vendedor se empareje consigo mismo).

*/

select
p.BusinessEntityID as ID,
p.FirstName as nombre,
p.LastName as apellido,
vendedor.TerritoryID as territorio
from Person.Person as p
inner join Sales.SalesPerson as vendedor
on p.BusinessEntityID = vendedor.BusinessEntityID

SELECT 
    p1.BusinessEntityID AS vendedor1,
    p2.BusinessEntityID AS vendedor2,
    p1.TerritoryID AS territorio
FROM Sales.SalesPerson AS p1
INNER JOIN Sales.SalesPerson AS p2
    ON p1.TerritoryID = p2.TerritoryID
    AND p1.BusinessEntityID < p2.BusinessEntityID

SELECT TerritoryID, COUNT(*) AS cantidad_vendedores
FROM Sales.SalesPerson
GROUP BY TerritoryID
ORDER BY TerritoryID;

SELECT 
    p1.BusinessEntityID AS vendedor1_id,
    per1.FirstName + ' ' + per1.LastName AS vendedor1_nombre,
    p2.BusinessEntityID AS vendedor2_id,
    per2.FirstName + ' ' + per2.LastName AS vendedor2_nombre,
    p1.TerritoryID AS territorio
FROM Sales.SalesPerson AS p1
INNER JOIN Sales.SalesPerson AS p2
    ON p1.TerritoryID = p2.TerritoryID
    AND p1.BusinessEntityID < p2.BusinessEntityID
INNER JOIN Person.Person AS per1
    ON p1.BusinessEntityID = per1.BusinessEntityID
INNER JOIN Person.Person AS per2
    ON p2.BusinessEntityID = per2.BusinessEntityID;

/*
Ejercicio 4 — Múltiples niveles de agregación

¿Cuál es el producto más vendido (por cantidad) dentro de cada categoría (ProductSubcategory)? 
Mostrá una sola fila por categoría, con el nombre del producto ganador y la cantidad vendida.

Pensalo con la misma familia de herramientas del "top 3 por territorio" que ya resolviste, pero acá querés solo el número 1 de cada grupo.
*/

with ventas_categoria as(
select
p.name as producto,
s.Name as categoria,
 SUM(det.OrderQty) as cantidad_vendida
from Production.Product as p 
inner join Production.ProductSubcategory as s
on p.ProductSubcategoryID = s.ProductSubcategoryID
inner join Sales.SalesOrderDetail as det
        on p.ProductID = det.ProductID
group by p.name,s.Name 
),
ranking AS (
    SELECT 
        producto,categoria,cantidad_vendida,
        ROW_NUMBER() OVER (PARTITION BY categoria ORDER BY cantidad_vendida DESC) AS posicion
    FROM ventas_categoria
)
SELECT producto,categoria,cantidad_vendida, posicion
FROM ranking
WHERE posicion = 1
ORDER BY categoria, posicion;

/*
Ejercicio 5 — El más difícil: comparación entre períodos

Para cada vendedor (SalesPerson), calculá el total vendido en 2013 y el total vendido en 2014, en la misma fila, 
y una columna con la diferencia entre ambos años. 
Los vendedores que no vendieron nada en alguno de los dos años deberían mostrar 0, no desaparecer del resultado.

Pista: acá vas a necesitar pensar en SUM combinado con CASE WHEN dentro del mismo agregado, 
algo como "sumá esto solo si se cumple tal condición" — es una técnica muy usada en reportes reales.
*/

SELECT 
    p.BusinessEntityID AS vendedor,

    SUM(
        CASE
            WHEN YEAR(ventas.OrderDate) = 2013
            THEN ventas.TotalDue
            ELSE 0
        END
    ) AS ventas_2013,

    SUM(
        CASE
            WHEN YEAR(ventas.OrderDate) = 2014
            THEN ventas.TotalDue
            ELSE 0
        END
    ) AS ventas_2014,

    SUM(
        CASE
            WHEN YEAR(ventas.OrderDate) = 2014
            THEN ventas.TotalDue
            ELSE 0
        END
    )
    -
    SUM(
        CASE
            WHEN YEAR(ventas.OrderDate) = 2013
            THEN ventas.TotalDue
            ELSE 0
        END
    ) AS diferencia

FROM Sales.SalesPerson AS p

LEFT JOIN Sales.SalesOrderHeader AS ventas
    ON p.BusinessEntityID = ventas.SalesPersonID

GROUP BY p.BusinessEntityID;
