# Guía de Reset - Entorno PRE

Este directorio contiene los scripts necesarios para realizar un reset completo y controlado del entorno de pruebas (PRE), sincronizándolo con los datos reales de Producción (PROD) y aplicando la lógica de la "Nueva Era" (Diciembre 2025).

## ⚠️ IMPORTANTE
Estos pasos están diseñados **únicamente para la instancia PRE** (`adventure-streak-pre`). No los ejecutes contra la instancia por defecto sin supervisión extrema.

## Flujo de Reset Completo (PRE)

Sigue estos pasos en orden desde la raíz de `backend-admin`:

### 1. Limpieza de PRE
Borra todos los documentos y subcolecciones de la instancia PRE para empezar desde cero.
```bash
npx ts-node scripts/reset/clear_pre_database.ts
```

### 2. Sincronización desde PROD
Copia los datos actuales de Producción a la instancia PRE de forma silenciosa.
```bash
npx ts-node scripts/sync/sync_prod_to_pre.ts
```

### 3. Ejecución del Reset Oficial (Fases 1-4)
Aplica la lógica de archivado y recalculado de la "Nueva Era". Este script es interactivo; asegúrate de confirmar cada fase.

```bash
npx ts-node scripts/reset/reset_dec_2025.ts
```

**Fases incluidas:**
*   **Fase 1 (Archive):** Mueve datos de actividades previos al 1 de Diciembre a la colección de archivo.
*   **Fase 2 (Cleanup):** Limpia colecciones globales (territorios, feed, notificaciones) para reconstruirlas.
*   **Fase 3 (User Reset):** Resetea XP, niveles y activa flags de sistema a los usuarios.
*   **Fase 4 (Reprocessing):** Reprocesa todas las actividades post-1 de Diciembre para regenerar el mapa y las estadísticas actuales.

## Verificación
Tras completar las 4 fases, puedes verificar el estado con:
```bash
npx ts-node scripts/reset/verify_pro_reset.ts
```
*(Nota: Aunque se llama `verify_pro_reset`, el script está configurado para leer de la instancia PRE si se ejecuta en este flujo).*
