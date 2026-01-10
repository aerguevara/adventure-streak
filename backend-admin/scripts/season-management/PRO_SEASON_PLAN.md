# Plan de Cambio de Temporada: Entorno PRO (Producción)

Guía paso a paso para la ejecución crítica del cambio de temporada en el entorno de producción.

## 1. Preparación y Backup
> [!CAUTION]
> **Backup Crítico**: Antes de empezar, realiza un backup manual de Firestore desde la consola de Google Cloud para el proyecto `adventure-streak`.

## 2. Activación de Modo Silencioso
El script de reset activa automáticamente el modo silencioso, pero se recomienda verificar que las funciones están listas para no enviar notificaciones de "territorio robado" durante el reprocesamiento masivo.

## Funcionamiento Interno del Reset

Es fundamental entender qué ocurre durante la ejecución para monitorizar posibles anomalías:

1.  **Fase 1 (Archivo)**: Los datos antiguos se mueven a colecciones `_archive`.
2.  **Fase 2 (Limpieza)**: Se vacía el mapa global de territorios y las reacciones.
3.  **Fase 3 (Usuarios)**: Se calcula el Prestigio (XP/5000), se guarda el historial de la temporada y se resetean todos los contadores a cero.
4.  **Fase 3.5 (Config)**: Se inyectan las nuevas reglas de juego y IDs de temporada.
5.  **Fase 4 (Reprocesamiento)**: Se fuerzan las actividades de la nueva temporada a procesarse de nuevo. Esto reconstruye el mapa de forma consistente.
6.  **Fase 5 (Cierre)**: Timestamp final y fin del modo mantenimiento.

## 3. Ejecución del Reset
Se recomienda realizar un **Dry Run** primero para verificar el alcance de los cambios sin afectar a los datos. El script final solicitará una confirmación manual por teclado en la ejecución real.

```bash
# 1. Simulación (RECOMENDADO)
npm run script scripts/season-management/season_reset_tool.ts PRO T1_2026 2026-01-01 "Temporada 1" --dry

# 2. Ejecución real en PRO (¡CUIDADO!)
npm run script scripts/season-management/season_reset_tool.ts PRO T1_2026 2026-01-01 "Temporada 1"
```

## 4. Fases de Post-Reset
1. **Verificación de Logs y Estado**: Ejecuta el script de verificación para asegurar que todas las actividades se han procesado correctamente.
   ```bash
   npm run script scripts/season-management/verify_activities_status.ts PRO
   ```
2. **Desactivación de Mantenimiento**: El script de reset desactivará el `silentMode` al finalizar.
3. **Smoke Test**: Abre la app con una cuenta real y verifica:
    - Transición de temporada (Modal).
    - Preservación de Prestigio.
    - Limpieza de `vengeance_targets`.

## 5. Comunicación
Una vez verificado, notifica a los usuarios a través de canales sociales o push (si se desea) sobre el inicio de la nueva temporada.
