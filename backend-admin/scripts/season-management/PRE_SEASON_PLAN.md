# Plan de Cambio de Temporada: Entorno PRE (Pruebas)

Este plan detalla los pasos para simular y validar un cambio de temporada utilizando el entorno de pre-producción (`adventure-streak-pre`).

## 0. Limpieza del Entorno PRE
El script `clear_database.ts` está restringido **exclusivamente** al entorno PRE por seguridad. Ejecútalo para asegurar un entorno limpio.

```bash
# Limpiar Base de Datos PRE (Protegido contra ejecución en PRO)
npm run script scripts/season-management/clear_database.ts
```

## 1. Sincronización de Datos Reales
Antes de probar el reset, es vital tener datos frescos de producción para asegurar que el archivo y el reprocesamiento funcionan con volúmenes reales.

```bash
# Sincronizar PROD -> PRE
npm run script scripts/season-management/sync_prod_to_pre.ts
```

## 2. Simulación (Dry Run)
Simula el reset para la nueva temporada (ej. `T1_2026`) empezando el 1 de Enero.

```bash
# Comando Dry Run en PRE
npm run script scripts/season-management/season_reset_tool.ts PRE T1_2026 2026-01-01 "Temporada 1" --dry
```
- **Verificar**: Revisa los logs para asegurar que el número de actividades a archivar y reprocesar es coherente.

## 3. Ejecución en PRE
Si la simulación es correcta, procede con la ejecución real sobre la base de datos PRE.

```bash
# Ejecución real en PRE
npm run script scripts/season-management/season_reset_tool.ts PRE T1_2026 2026-01-01 "Temporada 1"
```

## Detalle de Fases del Script (season_reset_tool.ts)

El script realiza las siguientes operaciones en orden secuencial para garantizar la integridad de los datos:

### Fase 1: Archivo de Datos Históricos 📁
- Selecciona documentos de `activities`, `feed` y `notifications` con fecha anterior a la "Start Date".
- Los mueve a `activities_archive`, `feed_archive` y `notifications_archive`.
- En el caso de actividades, el movimiento es recursivo (incluye subcolecciones).

### Fase 2: Limpieza del Estado Global 🧹
- **Wipe del Mapa**: Borra todos los documentos de `remote_territories`.
- **Reacciones**: Borra `activity_reactions` y `activity_reaction_stats` (se regenerarán al reprocesar).
- **Limpieza de Actividades Actuales**: Para las actividades que NO se archivan (posteriores a la fecha de inicio), borra su subcolección `territories` y el campo `processingStatus`.

### Fase 3: Prestigio y Reset de Usuarios 👤
- **Prestigio**: Convierte el XP acumulado en puntos de Prestigio (1 punto por cada 5.000 XP).
- **Historial**: Crea una entrada en `seasonHistory` con el resumen de la temporada que termina.
- **Reset de Contadores**: Pone a 0 el XP seasonal, celdas dominadas, rachas y estadísticas de combate.
- **Venganzas**: Borra la subcolección `vengeance_targets` de cada usuario.

### Fase 3.5: Configuración de la Nueva Temporada ⚙️
- Actualiza `config/gameplay` con el nuevo `SeasonID`, nombre y la fecha de reset global.
- Ajusta parámetros como `territoryExpirationDays` para el nuevo periodo.

### Fase 4: Reprocesamiento Retroactivo 🔄
- Busca las actividades realizadas desde la fecha de inicio de la temporada.
- Elimina los cálculos previos (`xpBreakdown`, `missions`, `territoryStats`).
- Cambia el estado a `pending`, disparando las Cloud Functions para reconstruir el mapa y el XP de forma exacta.

### Fase 5: Finalización 🏁
- Registra el timestamp final del reset en `config/gameplay`.
- Desactiva el `silentMode` (si no hubo errores).

## 4. Verificación en la App
Una vez finalizado, abre la app apuntando al entorno PRE:

- **Modal de Temporada**: ¿Aparece el resumen de la temporada anterior?
- **XP y Contadores**: ¿El XP de temporada es 0 pero el Prestigio ha aumentado?
- **Mapa**: ¿El mapa se ha reconstruido correctamente basándose solo en actividades desde el 1 de Enero?
- **Archivo**: Verifica en Firestore que las actividades antiguas están en `activities_archive`.
