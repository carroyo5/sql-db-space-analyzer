# 📊 SQL Server Database Space Usage Analyzer
## 🚀 Características

- Consulta el tamaño reservado, usado, y no utilizado por tabla.
- Identifica el tamaño ocupado por datos e índices.
- Incluye estadísticas de fragmentación de índices.
- Calcula el tamaño total por tabla en GB.
- Excluye tablas del sistema para centrarse en datos relevantes.
- Soporte para tablas internas y estructuras fragmentadas.

## 📌 Requisitos

- Permisos para ejecutar vistas del sistema como `sys.dm_db_partition_stats`, `sys.indexes`, `sys.dm_db_index_physical_stats`, etc.

## 📂 Estructura del script

El script incluye varias CTEs como:

- `TableStats`: Estadísticas de filas y páginas por tabla.
- `InternalTableStats`: Uso de espacio por tablas internas.
- `IndexedFragmentationDetails`: Detalles de fragmentación por índice.
- `IndexFragmentation`: Agregación de fragmentación de índices por objeto.

Al final, se genera un resultado con columnas como:

- `table_name`
- `Cantidad de Campos`
- `Reserved KB`, `Data KB`, `Index_size KB`, `Unused KB`
- `Tamaño Total GB`
- `Nombre del índice`, `Tipo de índice`, `Porcentaje de fragmentación`

## Ejemplo de salida

| table_name           | Cantidad de Campos | Reserved KB | Data KB | Index_size KB | Unused KB | Tamaño Total GB | Nombre del índice | Tipo de índice | Porcentaje de fragmentación |
|----------------------|--------------------|-------------|---------|----------------|------------|------------------|--------------------|-----------------|-----------------------------|
| dbo.MyTable          | 1500000            | 24000       | 16000   | 5000           | 3000       | 0.02             | 1- PK_MyTable      | 1- CLUSTERED    | 1- 89.5%                    |

## 🛠️ Uso

1. Cambia a la base de datos deseada con `USE [NombreDeTuBaseDeDatos]`.
2. Ejecuta todo el script.
