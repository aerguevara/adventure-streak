# Adventure Streak — Sistema de juego y funcionalidades

Documentación de alto nivel del estado actual de la app (código en `Adventure Streak/`) con foco en el sistema de gamificación y los flujos principales.

## Panorama general
- App iOS/SwiftUI con pestañas de Progreso, Mapa, Feed social y Ranking (`ContentView.swift`, `Views/MainTabView.swift`).
- Autenticación: Sign in con Apple, invitado anónimo y placeholder para Google (`Services/AuthenticationService.swift`, `ViewModels/LoginViewModel.swift`).
- Onboarding pide permisos de localización, notificaciones y HealthKit (`ViewModels/OnboardingViewModel.swift`).
- Integraciones: HealthKit para importar workouts y rutas, WatchConnectivity para recibir actividades desde Apple Watch, Firebase (condicional) para usuarios, feed, ranking, territorios y badges.

## Flujo de actividad y procesamiento
1. **Captura de ruta**: `LocationService` obtiene posiciones (filtro 10 m) y construye `RoutePoint` mientras una sesión está activa (`ViewModels/MapViewModel.swift`).
2. **Fin de sesión**: `MapViewModel.stopActivity` arma un `ActivitySession` y lo envía al `GameEngine`.
3. **Importación de workouts**: `ViewModels/WorkoutsViewModel` y `ViewModels/HistoryViewModel` consultan HealthKit, filtran duplicados (últimos 7 días), descargan rutas y generan sesiones. `WorkoutsViewModel` reprocese cada sesión con `GameEngine` para tener XP/misiones/territorios consistentes.
4. **Recepción desde watch**: `Services/WatchSyncService` decodifica `ActivitySession` recibido vía `WCSession` y lo deja listo para que la app lo procese.

## Motor de juego (`Services/GameEngine.swift`)
Pipeline central (bloquea en MainActor):
1. Guarda la actividad en `ActivityStore`.
2. Construye el contexto XP del usuario (`GamificationRepository.buildXPContext`).
3. Procesa el territorio (`TerritoryService.processActivity`) y obtiene `TerritoryStats` (nuevas, defendidas, recapturadas).
4. Clasifica misiones cumplidas (`MissionEngine.classifyMissions`).
5. Calcula XP (`GamificationService.computeXP`) combinando base + territorio + bonificaciones.
6. Actualiza la actividad con XP/territorio/misiones y la persiste.
7. Aplica el XP al perfil (`GamificationService.applyXP`) recalculando nivel.
8. Genera eventos de feed por cada misión y, si corresponde, por expansión territorial destacada (`FeedRepository.postEvent`).

## Sistema de territorios
- **Grid**: celdas de 0.002° (~222 m) con expiración a 7 días (`Models/TerritoryGrid.swift`, `Models/TerritoryCell.swift`).
- **Cálculo**: `TerritoryService.calculateTerritories` interpola puntos cada 20 m para no dejar huecos y clasifica cada celda como nueva, defendida o recapturada. Estadísticas devueltas en `TerritoryStats`.
- **Persistencia local**: `TerritoryStore` guarda celdas en JSON, limpia expiradas al cargar y con temporizador, y permite borrados por pérdida de control.
- **Multijugador**: `TerritoryRepository` sincroniza celdas en Firestore (`remote_territories`), restaura conquistas propias faltantes y marca rivales para renderizarlos.
- **Render de mapa**: `MapView` pinta polígonos verdes (propios) y naranjas (rivales) con diffs para minimizar parpadeos; filtra a 500 celdas visibles recientes.

## Sistema de XP y niveles (`Models/XPModels.swift`, `Services/GamificationService.swift`)
- **Config**:
  - Distancia mínima 0.5 km, duración mínima 5 min para generar XP base.
  - XP base por km = `baseFactorPerKm` (10) ajustado por tipo: run 1.2, walk/hike 0.9, bike 0.7, other 1.0. Tope diario de XP base: 300.
  - Territorio: nueva celda 8 XP (máx. 50 nuevas por actividad), defendida 3 XP, recapturada 12 XP.
  - Streak: 10 XP por semana de racha activa.
  - Récord semanal: si supera el mejor de la semana, 30 XP + 5 XP por km de mejora (solo si el mejor previo ≥5 km).
- **Nivel**: `level = 1 + totalXP/1000`; helpers para barra de progreso (`progressToNextLevel`).
- **Contexto** (`XPContext`): distancia semanal actual, mejor distancia semanal histórica, semanas de racha, XP base ganado hoy y estado persistente (XP total, nivel, racha).

## Misiones (`Services/MissionEngine.swift`, `Models/Mission.swift`)
- **Territorial**: según celdas nuevas; rareza escala Common (<5), Rare (5-14), Epic (15-19), Legendary (20+). Nombres: Exploración Inicial, Expedición, Conquista Épica, Dominio Legendario.
- **Recaptura**: si hay recapturedCells, misión épica “Reconquista”.
- **Racha**: si hay streak activa, misión de progresión “Racha Activa” (Rare/Epic según semanas).
- **Récord semanal**: si la distancia semanal supera el mejor histórico, misión “Nuevo Récord Semanal” (Epic/Legendary si mejora >10 km).
- **Esfuerzo físico**: detecta alta intensidad por pace (<6 min/km running, <3 biking, <12 walk/hike); genera misión común o rara (“Esfuerzo Destacado” / “Sprint Intenso”).
- Las misiones adjuntan rareza y se guardan en la actividad para mostrar en UI y feed.

## Logros y badges (`Models/Badge.swift`, `Services/GamificationRepository.swift`)
- Definiciones estáticas combinadas con Firestore para saber cuáles están desbloqueados:
  - `first_steps`, `week_streak`, `explorer_novice` (10 celdas), `marathoner` (42 km acumulados), `defensor` (recapturar territorio).
- `GamificationRepository.fetchBadges` marca `isUnlocked` en base a la colección `users/{id}/badges`. `awardBadge` permite registrar nuevos logros en remoto.
- Vista dedicada en `Views/BadgesView.swift` y atajos en el dashboard de Progreso.

## Social, feed y ranking
- **Feed**: `FeedRepository.observeFeed` escucha la colección `feed` (últimos 20). `GameEngine` publica eventos por misiones y expansión territorial; `SocialService.createPost` crea eventos manuales. `FeedViewModel` calcula resúmenes semanales locales.
- **Social feed**: `SocialService` fusiona eventos + estado de follow para producir `SocialPost`; `SocialFeedView` muestra tarjetas con distancia, XP y nuevas zonas.
- **Follow**: alta/baja en subcolección `following` del usuario actual.
- **Ranking**: `GamificationRepository.fetchWeeklyRanking` ordena usuarios por XP (proxy semanal), `RankingViewModel` marca al usuario actual y permite seguir a otros; `UserSearchViewModel` hace búsqueda por nombre.

## Perfil y visualización de progreso
- **Dashboard Progreso** (`Views/WorkoutsView.swift`): muestra nivel/XP, racha semanas, barra de progreso a siguiente nivel, resumen territorial semanal y cards gamificadas por actividad (`Views/GamifiedWorkoutCard.swift` con XP, rareza, misiones, territorios).
- **Perfil** (`ViewModels/ProfileViewModel.swift`): observa `GamificationService` para XP/nivel en vivo, calcula streak y territorios/actividades de la última semana; permite sign-out que limpia stores locales y feed.
- **Historico/Import**: `HistoryViewModel` mantiene lista de actividades y auto-importa de HealthKit al iniciar.

## Persistencia y utilidades
- `ActivityStore` y `TerritoryStore` guardan JSON en Documents con helpers para calcular rachas y limpiar expirados (`Persistence/JSONStore.swift`).
- `NotificationService` dispara locales para territorio en riesgo o perdido.
- `LocationService` mantiene permisos y estado de tracking (con opción de solo monitoreo sin grabar ruta).
- Extensión de color y assets para la UI; mapas en `Views/MapView.swift` con diffing de overlays.
