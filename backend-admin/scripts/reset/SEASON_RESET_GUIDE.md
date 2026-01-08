# Guía de Reset de Temporada

Esta utilidad permite realizar una transición limpia entre temporadas de Adventure Streak, asegurando que el progreso anterior se convierta en **Prestigio** y el nuevo periodo comience con datos precisos.

## Uso del Script

El script se encuentra en `backend-admin/scripts/reset/season_reset_tool.ts`.

### Comandos Comunes

### Comandos Comunes

```bash
# Simular un inicio retroactivo al 1 de Enero de 2026 en PRE
npm run script scripts/reset/season_reset_tool.ts PRE T1_2026 2026-01-01 "Temporada 1" --dry

# Ejecución real en PRO para la Temporada 1
npm run script scripts/reset/season_reset_tool.ts PRO T1_2026 2026-01-01 "Temporada 1"
```

### Parámetros
1. **Entorno**: `PRE` o `PRO`.
2. **Season ID**: Identificador de la temporada (ej. `T1_2026`).
3. **Start Date**: Fecha de inicio de la temporada (YYYY-MM-DD). Todas las actividades desde esta fecha serán preservadas y reprocesadas.
4. **Season Name**: Nombre legible de la temporada (ej. "Temporada 1").
5. **--dry**: (Opcional) Simula la ejecución sin realizar cambios en la base de datos.

## Fases de Operación

1. **Archivo 📁**: Los datos anteriores a la fecha de inicio se mueven a colecciones de archivo (`activities_archive`, etc.).
2. **Limpieza 🧹**: Se vacía el mapa de territorios y se limpian reacciones y notificaciones pendientes.
3. **Prestigio ⭐️**: El XP actual de los usuarios se convierte en prestigio (1 punto por cada 5000 XP) y se resetean los contadores.
4. **Reprocesamiento 🔄**: Se vuelven a procesar todas las actividades realizadas desde la fecha de inicio. Esto reconstruye el mapa de territorios y el XP de temporada de forma exacta.

## Precauciones
- **Silent Mode**: El script activa automáticamente el modo mantenimiento para evitar notificaciones basura durante el reprocesamiento.
- **Backups**: Aunque el script archiva datos, se recomienda realizar un backup de Firestore antes de ejecuciones masivas en PRO.
- **PRO Confirmation**: En entorno PRO, el script solicitará una confirmación manual por teclado.
