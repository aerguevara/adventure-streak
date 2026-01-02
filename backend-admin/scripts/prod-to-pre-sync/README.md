# Sincronización de Datos (PRO a PRE)

Este directorio contiene los scripts oficiales para realizar un volcado completo de datos desde el entorno de Producción (PRO) al entorno de Pre-producción (PRE).

## Scripts

### 1. `clear_pre_database.ts`
Borra **completamente** el contenido de la base de datos `adventure-streak-pre`.
-   Limpia colecciones principales y subcolecciones de forma recursiva.
-   Incluye colecciones de actividades, feed, notificaciones, territorios y usuarios.

**Uso:**
```bash
npm run script scripts/prod-to-pre-sync/clear_pre_database.ts
```

### 2. `sync_prod_to_pre.ts`
Copia todos los datos desde la base de datos por defecto (`PRO`) a la instancia `adventure-streak-pre` (`PRE`).
-   Activa automáticamente el `silentMode` en PRE para evitar el envío de notificaciones durante el volcado.
-   Mantiene la estructura de documentos y subcolecciones.

**Uso:**
```bash
npm run script scripts/prod-to-pre-sync/sync_prod_to_pre.ts
```

## Flujo Recomendado para Reset de PRE

Para iniciar el entorno PRE desde cero con los datos actuales de PRO:

1.  **Limpiar PRE**: Ejecutar `clear_pre_database.ts`.
2.  **Sincronizar**: Ejecutar `sync_prod_to_pre.ts`.

> [!IMPORTANT]
> Asegúrate de que el archivo de credenciales `Docs/serviceAccount.json` tenga los permisos necesarios para ambas bases de datos.
