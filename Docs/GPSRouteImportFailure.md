# Fallo: actividades importadas sin ruta GPS

## Escenario reportado
- Entreno outdoor de ~1.5 km (1 h) aparece en la app sin puntos GPS; no genera territorios.
- El mismo usuario hace otra ruta simultánea con otro usuario (misma distancia y trayecto). Para el compañero la importación incluye la ruta y territorios, pero para el usuario inicial vuelve a fallar.
- HealthKit sí muestra la ruta completa.

## Posibles causas (ordenadas por probabilidad)
1. **Consulta de ruta en HealthKit devuelve vacío/`nil` y guardamos la actividad igualmente.**
   - La importación construye siempre la sesión aun cuando `fetchRoute` no traiga puntos (`routePoints ?? []`). El resultado se persiste con `route` vacío, por lo que el GameEngine calcula 0 territorios y XP reducido. Si el primer intento falla, la sesión queda registrada sin ruta y no se reintenta con los datos correctos. 
2. **Permiso o disponibilidad puntual de `HKWorkoutRoute` durante la importación inicial.**
   - Aunque el usuario tenga la ruta en HealthKit, si al momento de importar la app no tiene permiso de lectura de `workoutRoute` o el `HKAnchoredObjectQuery` devuelve error, la ruta llega como `nil`. La actividad se marca como importada y luego queda bloqueada por el filtro de duplicados.
3. **Filtro de duplicados por `HKWorkout.uuid` impide reimportar con la ruta.**
   - Una vez que la actividad se guarda (incluso sin ruta), el siguiente arranque descarta el workout porque su UUID ya está en `ActivityStore`. Así no hay segunda oportunidad para rehacer la ruta aunque HealthKit sí la proporcione.
4. **Workouts con múltiples `HKWorkoutRoute` samples o segmentos no cubiertos.**
   - `fetchRoute` sólo usa el primer `HKWorkoutRoute` (`routes.first`). Si el entrenamiento se partió en varios segmentos (ej. grabado por Watch y Phone o reanudado tras pausa larga), podríamos estar leyendo un fragmento vacío y perder el resto de puntos.
5. **Clasificación como indoor por metadatos y ruta ignorada en procesamiento posterior.**
   - Si el workout trae `HKMetadataKeyIndoorWorkout = true` por error, `activityType(for:)` lo marca como `.indoor`. Las sesiones indoor pueden procesarse sin ruta o tener reglas de XP distintas; si además el `route` se queda vacío, el motor descarta territorios.

## Recomendaciones de mitigación
- Añadir reintentos y logs explícitos cuando `fetchRoute` devuelva vacío antes de guardar la actividad.
- Permitir reimportar/actualizar una actividad si originalmente se guardó con `route.count == 0` pero HealthKit ya tiene puntos.
- Leer y unir todos los `HKWorkoutRoute` asociados al workout para cubrir rutas segmentadas.
- Registrar métricas de permiso/errores de `HKAnchoredObjectQuery` para detectar importaciones sin ruta.
