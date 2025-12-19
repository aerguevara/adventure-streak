# Procesado de actividades, territorios y XP (Adventure Streak)

Guía detallada para replicar el pipeline en otro proyecto.

## 1. Entrada y normalización
- **Fuente**: HealthKit.
- **Datos mínimos por actividad** (`ActivitySession`):
  - `id`: UUID de `HKWorkout`.
  - `startDate`, `endDate`.
  - `activityType`: mapeo de `HKWorkoutActivityType` (run, walk, bike, hike, indoor, otherOutdoor).
  - `distanceMeters`, `durationSeconds`.
  - `workoutName`: título de HealthKit si existe, si no, fallback por tipo.
  - `route`: lista de puntos GPS (vacía para indoor/sin ruta).
- **Ventana de importación**: se filtran entrenos con `startDate/endDate >= cutoffDate`, donde  
  `cutoffDate = today - workoutLookbackDays` (config remota).

## 2. Config remota (Firestore `config/gameplay`)
- `loadHistoricalWorkouts: Bool` → permite o no importar histórico.
- `workoutLookbackDays: Int` → ventana de días para traer entrenos.
- `territoryExpirationDays: Int` → días hasta que expira la propiedad de una celda.

## 3. Mapeo de ruta a territorios
- **Grid**: celdas regulares ~0.002° lat/lon. Cada celda (`TerritoryCell`) tiene:
  - `id`: `"x_y"` (índices del grid).
  - `centerLatitude/Longitude`.
  - `boundary`: polígono (4 puntos) calculado a partir del centro/tamaño.
  - `lastConqueredAt`, `expiresAt`.
  - `ownerUserId`, `ownerDisplayName`, `ownerUploadedAt` (opcional).
- **Asignación de puntos**: cada punto de la ruta se asigna a su celda; se deduplican celdas.

## 4. Prefetch / Estado remoto
- Antes de clasificar una celda, se consulta el store local (`TerritoryStore`) que se sincroniza con:
  - Colección `remote_territories` (propiedad actual global).
  - Subcolección `activities/{id}/territories` (celdas generadas por cada actividad).
- Si falta alguna celda en local, se puede prefetchar del remoto para asegurar dueño y `lastConqueredAt`.

## 5. Clasificación de celdas (por actividad)
Para cada celda tocada por la ruta:
- Se compara el tiempo de la actividad (`endDate`) vs `lastConqueredAt` remoto/local.
- **Casos**:
  - **Nueva**: sin dueño o `expiresAt < now` → propietario pasa a ser el usuario.
  - **Defendida/Renovada**: dueño actual == usuario y la actividad es más reciente → actualiza `lastConqueredAt`, recalcula `expiresAt`.
  - **Robada/Recapturada**: dueño distinto y la actividad es más reciente → cambia propietario a usuario, actualiza `lastConqueredAt/ExpiresAt`.
  - Si la actividad es anterior a `lastConqueredAt` del dueño vigente → se ignora (no cambia propiedad).
- `expiresAt = lastConqueredAt + territoryExpirationDays`.

## 6. Persistencia de territorios
- **Global**: colección `remote_territories`, documento por celda (id = `"x_y"`), campos:
  ```json
  {
    "centerLatitude": Double,
    "centerLongitude": Double,
    "boundary": [ { "latitude": Double, "longitude": Double } ],
    "lastConqueredAt": Timestamp,
    "expiresAt": Timestamp,
    "ownerUserId": String,
    "ownerDisplayName": String,
    "ownerUploadedAt": Timestamp,
    "activityId": String
  }
  ```
- **Por actividad**: subcolección `activities/{activityId}/territories`, con chunks si es necesario. Cada doc (chunk) guarda un array de `TerritoryCell` para reconstruir el minimapa/detalle.

## 7. Estadísticas de territorio por actividad
- `TerritoryStats` por actividad:
  - `newCellsCount`
  - `defendedCellsCount`
  - `recapturedCellsCount`
- Se adjunta a `ActivitySession` y se sube a `activities` en Firestore.

## 8. Cálculo de XP (GamificationService)
- Entradas:
  - `ActivitySession` (tipo, distancia, duración).
  - `TerritoryStats` (nuevas/defendidas/recapturadas).
  - Contexto de usuario (XP/Level previos).
- Reglas (resumen):
  - **Base XP**: según tipo y distancia/duración. Outdoor con ruta otorga más; indoor/sin ruta usa una tabla reducida (ej: indoor XP por minuto).
  - **Territorio XP**: bonus por `newCellsCount`, menor por `defendedCellsCount`, y otro para `recapturedCellsCount`.
  - **Streak / récords**: si aplica, suma XP extra.
  - **Badges**: XP adicional si se desbloquea un badge.
- Resultado: `xpBreakdown` con campos (ejemplo):
  ```json
  {
    "total": 120,
    "xpBase": 70,
    "xpTerritory": 30,
    "xpStreak": 10,
    "xpWeeklyRecord": 5,
    "xpBadges": 5
  }
  ```
  - Se aplica al usuario (suma XP, recalcula nivel) y se guarda en `ActivitySession`.

### 8.1 Detalle de factores XP (XPConfig)
- Umbrales mínimos: `minDistanceKm = 0.5 km`, `minDurationSeconds = 300s (5 min)`.
- Límite diario base: `dailyBaseXPCap = 300` (solo cuenta base XP hacia el cap).
- Base XP por km: `baseFactorPerKm = 10`.
  - Multiplicadores por tipo:
    - Run: `factorRun = 1.2`
    - Bike: `factorBike = 0.7`
    - Walk/Hike: `factorWalk = 0.9`
    - Other outdoor: `factorOther = 1.0`
    - Indoor: `factorIndoor = 0.5`
  - Outdoor sin ruta (o indoor/sin ruta): se usa `baseFactorPerKm * factorIndoor`.
- Indoor específico: si tipo = indoor y cumple duración mínima, `XP = minutos * indoorXPPerMinute (3.0)`, capado por `dailyBaseXPCap - todayBaseXPEarned`.
- Territorio XP:
  - `xpPerNewCell = 8` (máximo `maxNewCellsXPPerActivity = 50` celdas cuentan como nuevas).
  - `xpPerDefendedCell = 3`
  - `xpPerRecapturedCell = 12`
  - Total territorio = new*8 + defended*3 + recaptured*12 (con límite en nuevas).
- Streak: `baseStreakXPPerWeek = 10 * currentStreakWeeks` (solo si la actividad mantiene streak, duración >= minDurationSeconds).
- Récord semanal:
  - Requiere `bestWeeklyDistanceKm >= minWeeklyRecordKm (5.0)`.
  - Si `newWeekDistanceKm > best`, XP = `weeklyRecordBaseXP (30) + (diffKm * weeklyRecordPerKmDiffXP (5))`.
- Badges: actualmente 0 en este proyecto (placeholder).
- Nivel: `level = 1 + totalXP/1000` (umbral por nivel = 1000 XP lineal).

## 9. Persistencia de la actividad
- Colección `activities` (doc id = activityId UUID):
  - Campos principales (`startDate`, `endDate`, `activityType`, `distanceMeters`, `durationSeconds`, `workoutName`…).
  - `xpBreakdown`, `territoryStats`, `missions` (si aplica).
  - `routeChunkCount` + subcolección `routes` (chunks de puntos) si la ruta es larga.
  - Subcolección `territories` con las celdas tocadas por esta actividad (chunks).

## 10. Feed social
- Se crea un `FeedEvent` en colección `feed`:
  ```json
  {
    "type": "weeklySummary",                // usado como genérico para actividad
    "date": Timestamp(endDate),
    "activityId": "…",                      // link al detalle/territorios
    "userId": "…",
    "relatedUserName": "Display Name",
    "userLevel": Int,
    "userAvatarURL": "…",
    "activityData": {
      "activityType": "walk",
      "distanceMeters": 3200,
      "durationSeconds": 1800,
      "xpEarned": 59,
      "newZonesCount": 2,
      "defendedZonesCount": 1,
      "recapturedZonesCount": 0
    }
  }
  ```
- El feed muestra métricas y, en el detalle, lee `activities/{id}/territories` para mostrar el minimapa de celdas (polígonos).

## 11. Estado local y sincronización
- `ActivityStore` guarda actividades en local (JSON); `TerritoryStore` guarda celdas.
- Al iniciar sesión o reingresar, `ActivityRepository.ensureRemoteParity` sincroniza:
  - Sube locales faltantes.
  - Baja remotas extra (con territorios asociados).
- `ProfileViewModel` recalcula y persiste:
  - `totalCellsConquered` (todas las celdas con owner == usuario).
  - `territoriesCount` (celdas con `lastConqueredAt >= cutoffDate`).
  - Se guardan en `users/{id}`: `totalCellsOwned`, `recentTerritories`.

## 12. Expiración y robustez
- Una celda expira si `expiresAt < now` → cualquiera puede reconquistarla como “Nueva”.
- Prefetch remoto antes de clasificar evita que actividades viejas sobrescriban dueños más recientes.
- Si una actividad ya existe en remoto, no se recalcula XP ni se reaplica al usuario.

## 13. Notificaciones (opcional)
- FCM token se guarda en `users/{id}.fcmTokens` (string único).
- Backend (Cloud Function) puede escuchar `feed` o `activities` y enviar notificación usando esos tokens.

## 14. Resumen de colecciones en Firestore
- `config/gameplay` : lookback, expiración, flags de import.
- `activities/{activityId}` + subcolecciones `routes` y `territories`.
- `remote_territories/{cellId}` : estado global de cada celda.
- `feed/{eventId}` : eventos del feed social vinculados a `activityId`.
- `users/{userId}` : perfil, XP/level, agregados de territorio, `fcmTokens` (string).

## 15. Estructuras de colecciones (ejemplos JSON)

### 15.1 `activities/{activityId}`
```json
{
  "id": "C197DBA5-7DEB-4CC0-8E9B-875BC16C5B03",
  "userId": "CVZ34x99UuU6fCrOEc8Wg5nPYX82",
  "startDate": "2024-06-20T13:50:00Z",
  "endDate": "2024-06-20T14:20:00Z",
  "activityType": "walk",
  "distanceMeters": 3200.0,
  "durationSeconds": 1800.0,
  "workoutName": "Evening Walk",
  "routeChunkCount": 1,
  "xpBreakdown": {
    "xpBase": 59,
    "xpTerritory": 16,
    "xpStreak": 10,
    "xpWeeklyRecord": 0,
    "xpBadges": 0,
    "total": 85
  },
  "territoryStats": {
    "newCellsCount": 2,
    "defendedCellsCount": 1,
    "recapturedCellsCount": 0
  },
  "missions": [
    { "name": "Exploración Inicial", "rarity": "common", "xpReward": 8 }
  ]
}
```

Subcolección `activities/{activityId}/routes` (chunks):
```json
{
  "id": "chunk_0",
  "points": [
    { "latitude": 40.4167, "longitude": -3.70325, "timestamp": "2024-06-20T13:52:00Z" },
    ...
  ]
}
```

Subcolección `activities/{activityId}/territories` (chunks):
```json
{
  "id": "chunk_0",
  "cells": [
    {
      "id": "-1837_20192",
      "centerLatitude": 40.4170,
      "centerLongitude": -3.7030,
      "boundary": [
        { "latitude": 40.4180, "longitude": -3.7040 },
        { "latitude": 40.4180, "longitude": -3.7020 },
        { "latitude": 40.4160, "longitude": -3.7020 },
        { "latitude": 40.4160, "longitude": -3.7040 }
      ],
      "lastConqueredAt": "2024-06-20T14:20:00Z",
      "expiresAt": "2024-06-27T14:20:00Z",
      "ownerUserId": "CVZ34x99UuU6fCrOEc8Wg5nPYX82",
      "ownerDisplayName": "Anyelo Reyes Guevara",
      "ownerUploadedAt": "2024-06-20T14:21:00Z",
      "activityId": "C197DBA5-7DEB-4CC0-8E9B-875BC16C5B03"
    }
  ]
}
```

### 15.2 `remote_territories/{cellId}`
```json
{
  "id": "-1837_20192",
  "centerLatitude": 40.4170,
  "centerLongitude": -3.7030,
  "boundary": [
    { "latitude": 40.4180, "longitude": -3.7040 },
    { "latitude": 40.4180, "longitude": -3.7020 },
    { "latitude": 40.4160, "longitude": -3.7020 },
    { "latitude": 40.4160, "longitude": -3.7040 }
  ],
  "lastConqueredAt": "2024-06-20T14:20:00Z",
  "expiresAt": "2024-06-27T14:20:00Z",
  "ownerUserId": "CVZ34x99UuU6fCrOEc8Wg5nPYX82",
  "ownerDisplayName": "Anyelo Reyes Guevara",
  "ownerUploadedAt": "2024-06-20T14:21:00Z",
  "activityId": "C197DBA5-7DEB-4CC0-8E9B-875BC16C5B03"
}
```

### 15.3 `feed/{eventId}` (vinculado a actividad)
```json
{
  "type": "weeklySummary",
  "date": "2024-06-20T14:20:00Z",
  "activityId": "C197DBA5-7DEB-4CC0-8E9B-875BC16C5B03",
  "title": "Activity Completed",
  "xpEarned": 85,
  "userId": "CVZ34x99UuU6fCrOEc8Wg5nPYX82",
  "relatedUserName": "Anyelo Reyes Guevara",
  "userLevel": 7,
  "userAvatarURL": "https://.../avatar.jpg",
  "activityData": {
    "activityType": "walk",
    "distanceMeters": 3200.0,
    "durationSeconds": 1800.0,
    "xpEarned": 85,
    "newZonesCount": 2,
    "defendedZonesCount": 1,
    "recapturedZonesCount": 0
  },
  "isPersonal": false
}
```

### 15.4 `users/{userId}`
```json
{
  "id": "CVZ34x99UuU6fCrOEc8Wg5nPYX82",
  "email": "user@example.com",
  "displayName": "Anyelo Reyes Guevara",
  "joinedAt": "2024-01-10T12:00:00Z",
  "avatarURL": "https://.../avatar.jpg",
  "xp": 7307,
  "level": 8,
  "totalCellsOwned": 47,
  "recentTerritories": 5,
  "fcmTokens": "fcm_token_1"
}
```
