USE [DatabaseName]
GO 

WITH TableStats AS (
    -- Obtener las estadísticas de partición de las tablas, agregadas por object_id
    SELECT 
        ps.object_id, 
        SUM(CASE WHEN ps.index_id < 2 THEN ps.row_count ELSE 0 END) AS row_count,  -- Contar filas solo para tablas y vistas
        SUM(ps.reserved_page_count) AS reserved_pages,  -- Páginas reservadas
        SUM(CASE 
                WHEN ps.index_id < 2 THEN (ps.in_row_data_page_count + ps.lob_used_page_count + ps.row_overflow_used_page_count) 
                ELSE (ps.lob_used_page_count + ps.row_overflow_used_page_count) 
            END) AS data_pages,  -- Páginas de datos
        SUM(ps.used_page_count) AS used_pages  -- Páginas usadas
    FROM sys.dm_db_partition_stats ps
    GROUP BY ps.object_id
),
InternalTableStats AS (
    -- Obtener las estadísticas para tablas internas (tipos 202, 204)
    SELECT 
        it.parent_id AS object_id, 
        SUM(ps.reserved_page_count) AS reserved_pages,  -- Páginas reservadas para tablas internas
        SUM(ps.used_page_count) AS used_pages  -- Páginas usadas para tablas internas
    FROM sys.dm_db_partition_stats ps
    INNER JOIN sys.internal_tables it ON it.object_id = ps.object_id
    WHERE it.internal_type IN (202, 204)
    GROUP BY it.parent_id
),

IndexedFragmentationDetails AS (
    -- CTE para obtener el detalle de índices con numeración por ROW_NUMBER()
    SELECT ix.object_id,
           ix.name AS index_name,
           ixs.index_type_desc,
           ROUND(ixs.avg_fragmentation_in_percent, 2) AS fragmentation_percent,
           ROW_NUMBER() OVER (PARTITION BY ix.object_id ORDER BY ixs.avg_fragmentation_in_percent DESC) AS row_num
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) ixs
    INNER JOIN sys.indexes ix ON ix.object_id = ixs.object_id
                              AND ix.index_id = ixs.index_id
),

IndexFragmentation AS (
    -- Obtener la fragmentación de índices con la numeracion
    SELECT ifd.object_id,
        STRING_AGG(CONVERT(VARCHAR, ifd.row_num) + '- ' + ifd.index_name, ', ') WITHIN GROUP (ORDER BY ifd.fragmentation_percent DESC) AS fragmented_indexes, 
		STRING_AGG(CONVERT(VARCHAR, ifd.row_num) + '- ' + ifd.index_type_desc, ', ') WITHIN GROUP (ORDER BY ifd.fragmentation_percent DESC) AS index_types, 
        STRING_AGG(CONVERT(VARCHAR, ifd.row_num) + '- ' + CONVERT(VARCHAR, ifd.fragmentation_percent) + '%', ', ') WITHIN GROUP (ORDER BY ifd.fragmentation_percent DESC) AS fragmentation_percentages
    FROM IndexedFragmentationDetails ifd
    GROUP BY ifd.object_id
)

SELECT 
    schem.name + '.' + allobj.name AS table_name,  -- Nombre completo de la tabla
    tstats.row_count AS [Cantidad de Campos],  -- Número de filas
    (tstats.reserved_pages + ISNULL(internalTstats.reserved_pages, 0)) * 8 AS [Reserved KB],  -- Espacio reservado en KB
    tstats.data_pages * 8 AS [Data KB],  -- Espacio ocupado por los datos en KB
    (CASE 
        WHEN (tstats.used_pages + ISNULL(internalTstats.used_pages, 0)) > tstats.data_pages 
        THEN (tstats.used_pages + ISNULL(internalTstats.used_pages, 0)) - tstats.data_pages 
        ELSE 0 
     END) * 8 AS [Index_size KB],  -- Tamaño de los índices en KB
    (CASE 
        WHEN (tstats.reserved_pages + ISNULL(internalTstats.reserved_pages, 0)) > tstats.used_pages 
        THEN (tstats.reserved_pages + ISNULL(internalTstats.reserved_pages, 0)) - tstats.used_pages 
        ELSE 0 
     END) * 8 AS [Unused KB],  -- Espacio no utilizado en KB
    CONVERT(DECIMAL(18, 2), ((tstats.reserved_pages + ISNULL(internalTstats.reserved_pages, 0)) * 8 - 
        ((CASE 
            WHEN (tstats.reserved_pages + ISNULL(internalTstats.reserved_pages, 0)) > tstats.used_pages 
            THEN (tstats.reserved_pages + ISNULL(internalTstats.reserved_pages, 0)) - tstats.used_pages 
            ELSE 0 
        END) * 8)) / 1024.0 / 1024.0) AS [Tamaño Total GB],  -- Tamaño total en GB
    ISNULL(ixf.fragmented_indexes, 'N/A') AS 'Nombre del índice',  -- Nombre del índice fragmentado
    ixf.index_types,  -- Tipo de índice
    ixf.fragmentation_percentages AS 'Porcentaje de fragmentación'  -- Fragmentación del índice en %
FROM TableStats tstats
LEFT JOIN InternalTableStats internalTstats ON internalTstats.object_id = tstats.object_id  -- Unir estadísticas de tablas internas
INNER JOIN sys.all_objects allobj ON tstats.object_id = allobj.object_id  -- Unir con la tabla de objetos para obtener el nombre de la tabla
INNER JOIN sys.schemas schem ON allobj.schema_id = schem.schema_id  -- Unir con los esquemas para obtener el esquema de la tabla
LEFT JOIN IndexFragmentation ixf ON ixf.object_id = tstats.object_id  -- Unir con fragmentación de índices 
WHERE allobj.type NOT IN ('S', 'IT') 
-- Excluir tablas de sistema y tablas internas
ORDER BY [Tamaño Total GB] DESC, [Cantidad de Campos] DESC;
