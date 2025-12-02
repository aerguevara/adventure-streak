# Análisis de fallos potenciales en la vista de territorios

## Contexto
La sincronización de territorios se ejecuta principalmente desde `MapViewModel` combinando el repositorio remoto (`territoryRepository`) y la caché local (`TerritoryStore`). El flujo actual intenta:
1) Filtrar y mostrar hasta 500 celdas visibles recientes (`visibleTerritories`).
2) Sincronizar pérdidas y recuperaciones de propiedad en segundo plano y reflejarlas en `otherTerritories`.

Con muchos jugadores simultáneos, este flujo puede romperse o mostrar estados incoherentes. A continuación se listan riesgos y sus consecuencias visibles.

## Riesgos de consistencia
- **Identidad del usuario vacía**: si `AuthenticationService.shared.userId` es `nil` o llega vacío, todas las celdas remotas se interpretan como rivales. Esto ocasiona que el pipeline elimine conquistas locales legítimas y las re-renderice como ajenas, provocando parpadeos y pérdida temporal de progreso propio.
- **Conflictos de propiedad no deterministas**: cuando dos jugadores conquistan la misma celda casi al mismo tiempo, el código solo conserva el último lote recibido y elimina las locales "perdidas" sin verificar el `timestamp`. En conexiones lentas o con servidores que entregan mensajes fuera de orden, el dueño mostrado puede alternar erráticamente.
- **Duplicados sin `removeDuplicates` estable**: la deduplicación se aplica al array completo de `RemoteTerritory`, pero si la estructura no implementa `Equatable` profunda o el orden cambia levemente, se disparan actualizaciones de UI innecesarias. Con muchos rivales esto puede provocar renderizados repetidos y consumo excesivo en la vista.
- **Límite de visibilidad parcial**: el recorte a 500 polígonos en `visibleTerritories` es independiente de `otherTerritories`. Si el repositorio remoto devuelve miles de rivales, se procesan todos en memoria aunque la UI solo pueda mostrar 500, afectando rendimiento en mapas densos.

## Riesgos de expiración y almacenamiento
- **Celdas expiradas no removidas a tiempo**: la eliminación se ejecuta al cargar y cuando se inserta un lote, pero no existe un temporizador periódico. En sesiones largas, las celdas caducadas pueden seguir pintándose en verde incluso después de expirar.
- **Grabaciones concurrentes**: `persist()` se ejecuta en `Task.detached` sin cancelar tareas previas. Con múltiples oleadas de actualizaciones (ej. muchos jugadores cercanos) puede generarse escritura simultánea del archivo JSON, dejando estados inconsistentes si ocurre un fallo durante la serialización.

## Riesgos de percepción en la UI
- **Parpadeo al perder celdas**: el pipeline elimina primero las celdas locales que ahora son ajenas y luego vuelve a insertarlas como rivales en la siguiente publicación. Esto puede generar un frame vacío en que la celda desaparece y reaparece con otro color, perceptible en mapas con zoom alto.
- **Actualización lenta de la región visible**: el filtro de visibilidad usa un `debounce` de 500 ms sobre la región y calcula en un hilo global. Desplazamientos rápidos pueden mostrar territorios atrasados medio segundo, creando discrepancia entre la posición actual y las celdas visibles.

## Escenarios con muchos jugadores
- Saturación de `otherTerritories` al recibir miles de rivales simultáneos, provocando:
  - Uso excesivo de CPU al recalcular diferencias de IDs y reconstruir `TerritoryCell` para restauraciones.
  - Animaciones y gestos del mapa menos fluidos por cambios constantes en la colección publicada.
- Cambios masivos de propiedad en eventos coordinados (ej. raids) que, combinados con una identidad vacía o con timestamps desordenados, pueden borrar temporalmente toda la caché local y repintarla como rival, confundiendo a los jugadores sobre quién controla la zona.

## Recomendaciones inmediatas
- Validar la identidad del usuario antes de procesar diffs y descartar paquetes hasta tener `userId` no vacío.
- Comparar `timestamp`/`expiresAt` al resolver conflictos de propiedad para conservar la conquista más reciente y evitar alternancias.
- Limitar y paginar `otherTerritories` igual que `visibleTerritories`, o aplicar un cap adicional para rivales fuera de la vista.
- Programar una limpieza periódica de celdas expiradas y serializar escrituras para evitar corridas de datos.
- Añadir trazas específicas (IDs y dueño esperado vs recibido) para diagnosticar casos con parpadeos de propiedad en producción.
