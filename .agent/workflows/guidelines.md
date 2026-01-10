---
description: Guía unificada para compilación de iOS y ejecución de scripts de backend
---
// turbo-all

# Guía de Desarrollo para Adventure Streak

## 0. Protocolo de Trabajo
> [!IMPORTANT]
> **Planificación Obligatoria**: Antes de realizar cualquier cambio en el código o ejecutar scripts, se debe presentar siempre un plan detallado de los cambios propuestos.
> 
> **Aprobación Requerida**: NUNCA se debe proceder con la implementación hasta que el usuario haya dado su "ok" o aprobación explícita al plan presentado.

Estas instrucciones deben seguirse siempre que se solicite compilar el proyecto iOS o ejecutar un script de administración/migración en el backend.

## 1. Compilación de la App iOS
> [!IMPORTANT]
> **Regla de Oro**: Por cada modificación realizada en el código Swift, se debe ejecutar siempre la compilación para verificar la integridad del proyecto y asegurar que no se introduzcan errores o advertencias.

Para verificar errores de sintaxis y asegurar que la app compila correctamente de forma optimizada:

```bash
./build_check.sh
```

### Análisis de Errores
- El script mostrará automáticamente los errores. Si necesitas más detalle, consulta `build_output.txt`.

---

## 2. Ejecución de Scripts de Backend (TypeScript)
Para scripts de migración, limpieza o debug en Firestore:

### Requisitos de Inicialización
Siempre inicializa el SDK de Firebase Admin con el Project ID y el Service Account correctos para evitar errores de detección de proyecto:

```typescript
import * as admin from 'firebase-admin';
import * as path from 'path';

// Ruta relativa desde functions/src/scripts/ hacia la raíz del proyecto
const serviceAccountPath = path.resolve(__dirname, '../../../../backend-admin/secrets/serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
  projectId: "adventure-streak" // Siempre incluir explícitamente
});
```

### Selección de Base de Datos
Como el proyecto usa múltiples bases de datos, especifica siempre el `databaseId`:

```typescript
// Para el entorno PRE
const db = admin.firestore().getFirestore("adventure-streak-pre");

// Para el entorno PRO
const db = admin.firestore().getFirestore("(default)");
```

### Ubicación y Ejecución
- Los scripts nuevos deben colocarse en `functions/firebase-function-notifications/functions/src/scripts/`.
- Antes de ejecutar un script nuevo, asegúrate de que no haya errores de compilación de TypeScript en esa carpeta.

---

## 3. Despliegue de Cloud Functions
Para desplegar cambios en la lógica del backend, se debe usar el despliegue selectivo para no afectar entornos innecesariamente:

### Desplegar solo en PRE:
```bash
firebase deploy --only functions:onNotificationCreatedPRE,functions:processActivityCompletePRE,functions:onReactionCreatedPRE,functions:onMockWorkoutCreatedPRE
```

### Desplegar solo en PROD:
```bash
firebase deploy --only functions:onNotificationCreated,functions:processActivityComplete,functions:onReactionCreated,functions:scheduledDailySync
```

### Desplegar Todo (Usar con precaución):
```bash
firebase deploy --only functions
```
