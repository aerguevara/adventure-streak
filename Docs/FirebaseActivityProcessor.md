# Cloud Function de Procesado de Actividades

Guía para portar la lógica de territorios, XP, misiones y feed al backend (Cloud Functions for Firebase).

## Objetivo
- El cliente sube una actividad "cruda" a `activities/{activityId}` con sus rutas en subcolección `routes`.
- Una Cloud Function procesa la actividad y escribe los resultados (XP, territorios, misiones, feed), de forma idempotente.
- Todos los resultados nuevos del cálculo (XP, misiones, territoryStats, metadatos de procesamiento) se guardan en la subcolección `activities/{activityId}/processing_v2` (el doc raíz solo lleva flags de estado/version).

## Flujo de alto nivel
1) Cliente crea/actualiza `activities/{activityId}` con `processingStatus = "pending"`, metadatos y `routeChunkCount`.
2) La función `onWrite`/`onCreate` espera a que existan todos los chunks de ruta declarados.
3) La función marca `processingStatus = "processing"` (lock simple), calcula territorios/XP/misiones/feed.
4) Escribe resultados en `activities/{activityId}/processing_v2/result` (o nombre equivalente) y marca en el doc raíz `processingStatus = "done"`.
5) Actualiza `remote_territories`, `users`, `feed`.
6) Idempotencia: si ya está `processingStatus = "done"` o existe doc en `processing_v2` con resultados, salir sin recalcular.

## Datos que envía el cliente
- `activityId` (UUID estable), `userId`.
- `startDate`, `endDate`, `activityType` ∈ {run, walk, bike, hike, otherOutdoor, indoor}.
- `distanceMeters`, `durationSeconds`, `workoutName?`.
- `routeChunkCount`, `routePointsCount`, subcolección `routes/chunk_{i}` con `points[] { latitude, longitude, timestamp }`.
- Opcional: `userDisplayName` para feed/territorios.

## Config remota (Firestore `config/gameplay`)
- `territoryExpirationDays` (default 7).
- `workoutLookbackDays`, `loadHistoricalWorkouts` (solo afectan import en cliente).

## Reglas de territorios
- Grid: celdas de tamaño fijo `cellSizeDegrees = 0.002`.  
  `cellId = floor(lon/size) + "_" + floor(lat/size)`.
- Cada celda guarda: `centerLat/Lon`, `boundary` (4 vértices), `lastConqueredAt`, `expiresAt`, `ownerUserId`, `activityId`, `uploadedAt`.
- Expiración: `expiresAt = activity.endDate + territoryExpirationDays`.
- Clasificación por celda (con `activity.endDate`):
  - Sin dueño o `expiresAt < now` → nueva, asignar dueño al usuario (`newCellsCount++`).
  - Dueño == usuario y actividad es más reciente → defendida (`defendedCellsCount++`), renovar fechas.
  - Dueño distinto y actividad más reciente → robada/recapturada (`recapturedCellsCount++`).
  - Si el dueño tiene `lastConqueredAt >= activity.endDate` y no expiró → ignorar (se conquistó después).
- Construcción de celdas desde ruta:
  - Interpolar puntos cada ~20 m entre pares consecutivos.
  - Mapear a `cellId`, deduplicar antes de clasificar.

## Cálculo de XP (XPConfig)
- Umbrales: `minDistanceKm = 0.5`, `minDurationSeconds = 300`, `dailyBaseXPCap = 300`.
- Factores base: `baseFactorPerKm = 10`.
  - Multiplicadores: run 1.2, bike 0.7, walk/hike 0.9, other 1.0, indoor 0.5.
  - Outdoor sin ruta → usar factor indoor.
  - Indoor sin distancia: `minutes * indoorXPPerMinute (3.0)` capado por el remanente del daily cap.
- Territorio XP: `new*8` (máx 50 nuevas), `defended*3`, `recaptured*12`.
- Streak: `10 * currentStreakWeeks` si duración ≥ min y mantiene racha.
- Récord semanal: si `bestWeeklyDistanceKm >= 5` y `newWeekDistance > best`, XP = `30 + (diffKm * 5)`.
- Badges: 0 (placeholder).
- Nivel: `level = 1 + floor(totalXP / 1000)`.

## Misiones (MissionEngine)
- Territorial según `newCellsCount` (common/rare/epic/legendary: 0-4, 5-14, 15-19, 20+).
- Recapture si `recapturedCellsCount > 0` (epic).
- Streak si `currentStreakWeeks > 0` (rare/epic si ≥4).
- Weekly record si `newWeekDistance > bestWeeklyDistance`.
- Physical effort (pace alto): run < 6 min/km, bike < 3 min/km, walk/hike < 12 min/km → rare/common.

## Feed
- Un evento por actividad. Tipo:
  - `territoryRecaptured` si `recaptured > 0`.
  - Si no, `territoryConquered` si hay nuevas/defendidas.
  - Si no, `distanceRecord`.
- Guarda: `activityId`, `xpEarned`, métricas de territorio, `distanceMeters`, `durationSeconds`, `userLevel`, `relatedUserName`, `isPersonal = true`.

## Pseudocódigo (TypeScript admin SDK)
```ts
export const processActivity = functions.firestore
  .document('activities/{activityId}')
  .onWrite(async (change, ctx) => {
    const after = change.after.exists ? change.after.data()! : null;
    if (!after || after.processingStatus === 'done') return;

    const chunkCount = after.routeChunkCount ?? 0;
    if (chunkCount > 0) {
      const routesSnap = await change.after.ref.collection('routes').get();
      if (routesSnap.size < chunkCount) return; // esperar que lleguen todos los chunks
    }

    await change.after.ref.set({ processingStatus: 'processing' }, { merge: true });

    const config = await loadConfig(); // lee config/gameplay o defaults
    const activity = await buildActivityFromFirestore(change.after.ref, after); // concatena route chunks
    const userId = after.userId;

    const xpCtx = await buildXPContext(userId); // xp, level, streakWeeks, bestWeeklyDistanceKm, todayBaseXPEarned, currentWeekDistanceKm

    let territoryResult = { cells: [], stats: emptyStats() };
    if (activity.activityType !== 'indoor' && activity.route.length > 0) {
      territoryResult = await computeTerritories({
        activity,
        userId,
        userName: after.userDisplayName ?? '',
        expirationDays: config.territoryExpirationDays ?? 7,
      });
    }

    const missions = classifyMissions(activity, territoryResult.stats, xpCtx);
    const xpBreakdown = computeXP(activity, territoryResult.stats, xpCtx);

    await firestore().runTransaction(async (tx) => {
      // 1) Activity status + puntero de procesamiento
      tx.set(change.after.ref, {
        processedAt: FieldValue.serverTimestamp(),
        processingStatus: 'done',
        processingVersion: 'v2'
      }, { merge: true });

      // 1b) Subcolección processing_v2 con resultados completos (no escribir XP/misiones en el doc raíz)
      tx.set(change.after.ref.collection('processing_v2').doc('result'), {
        xpBreakdown,
        territoryStats: territoryResult.stats,
        missions,
        routePointsCount: activity.route.length,
        processingVersion: 'v2',
        processedAt: FieldValue.serverTimestamp()
      }, { merge: true });

      // 2) Subcolección territories (chunks de ~200)
      chunk(territoryResult.cells, 200).forEach((cells, i) => {
        tx.set(change.after.ref.collection('territories').doc(`chunk_${i}`), {
          order: i, cells, cellCount: cells.length
        }, { merge: true });
      });

      // 3) remote_territories (upsert si es más reciente o estaba expirado)
      for (const cell of territoryResult.cells) {
        const ref = firestore().collection('remote_territories').doc(cell.id);
        tx.set(ref, {
          userId,
          centerLatitude: cell.centerLatitude,
          centerLongitude: cell.centerLongitude,
          boundary: cell.boundary,
          expiresAt: cell.expiresAt,
          activityEndAt: cell.lastConqueredAt,
          activityId: activity.id,
          timestamp: cell.lastConqueredAt,
          uploadedAt: FieldValue.serverTimestamp()
        }, { merge: true });
      }

      // 4) Usuario (XP/level/streak/agregados)
      const newTotalXP = (xpCtx.gamificationState.totalXP ?? 0) + xpBreakdown.total;
      const newLevel = 1 + Math.floor(newTotalXP / 1000);
      const newWeekDistance = xpCtx.currentWeekDistanceKm + (activity.distanceMeters / 1000);
      const newBestWeek = Math.max(xpCtx.bestWeeklyDistanceKm ?? 0, newWeekDistance);

      tx.set(firestore().collection('users').doc(userId), {
        xp: newTotalXP,
        level: newLevel,
        currentStreakWeeks: xpCtx.currentStreakWeeks, // recalcular si se rompe/extendió racha
        currentWeekDistanceKm: newWeekDistance,
        bestWeeklyDistanceKm: newBestWeek,
        recentTerritories: FieldValue.increment(
          territoryResult.stats.newCellsCount +
          territoryResult.stats.recapturedCellsCount +
          territoryResult.stats.defendedCellsCount
        ),
        lastUpdated: FieldValue.serverTimestamp()
      }, { merge: true });

      // 5) Feed event
      tx.set(firestore().collection('feed').doc(`activity-${activity.id}-summary`), {
        type: pickFeedType(territoryResult.stats),
        date: activity.endDate,
        activityId: activity.id,
        title: missions[0]?.name ?? 'Actividad completada',
        subtitle: buildSubtitle(missions, territoryResult.stats),
        xpEarned: xpBreakdown.total,
        userId,
        relatedUserName: after.userDisplayName ?? '',
        userLevel: newLevel,
        activityData: {
          activityType: activity.activityType,
          distanceMeters: activity.distanceMeters,
          durationSeconds: activity.durationSeconds,
          xpEarned: xpBreakdown.total,
          newZonesCount: territoryResult.stats.newCellsCount,
          defendedZonesCount: territoryResult.stats.defendedCellsCount,
          recapturedZonesCount: territoryResult.stats.recapturedCellsCount
        },
        isPersonal: true
      });
    });
  });
```

## Helpers a implementar
- `buildActivityFromFirestore(ref, after)`: concatena los `routes/chunk_i` en orden; si `routeChunkCount = 0`, ruta vacía.
- `computeTerritories({ activity, userId, userName, expirationDays })`:
  1. Construye el set de `cellIds` de la ruta (interpolando).
  2. Lee `remote_territories` por chunks de 10 ids.
  3. Aplica las reglas de clasificación (con `activity.endDate` y `expiresAt`).
  4. Devuelve celdas actualizadas + `stats { new, defended, recaptured }`.
- `buildXPContext(userId)`: carga XP/level/streak, `bestWeeklyDistanceKm`, `currentWeekDistanceKm`, `todayBaseXPEarned` (opcional sumar base XP de actividades de hoy).
- `classifyMissions`, `computeXP`, `pickFeedType`, `buildSubtitle` siguiendo las reglas arriba.

## Notas de idempotencia y robustez
- Revisar `processingStatus` antes de procesar.  
- Si faltan chunks de ruta, salir sin error; el siguiente write disparará la función.  
- Al reintentar, la transacción se encarga de merges sin duplicar XP/feed.  
- Evitar recálculo si ya existe `xpBreakdown` o `processingStatus = done`.  
