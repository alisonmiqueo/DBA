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
