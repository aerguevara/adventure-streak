# Adventure Streak - Documentación Técnica Completa 🎮

Este documento sirve como la base de conocimiento definitiva para el funcionamiento interno de Adventure Streak, detallando procesos, cálculos, comportamientos y la lógica de gamificación.

---

## 1. Sistema de Gamificación (XP y Niveles)

La progresión del usuario se basa en la acumulación de **Experiencia (XP)**, la cual se traduce directamente en **Niveles**.

### 1.1. Fórmula de Nivel
El nivel se calcula de forma lineal basándose en la XP total acumulada:
> **Nivel = 1 + truncar(XP Total / 1000)**

Cada nivel requiere exactamente 1000 XP adicionales.

### 1.2. Cálculos de XP (Detalle por Categoría)

La XP total de una actividad es la suma de:
`XP Total = XP Base + XP Territorio + XP Racha + XP Récord Semanal + XP Insignias`

#### A. XP Base (Esfuerzo Físico)
Se basa en el tiempo (Indoor) o la distancia (Outdoor), con requisitos mínimos de **0.5 km** y **5 minutos**. Existe un **Cap Diario de 300 XP** para esta categoría.

| Tipo de Actividad | Factor Multiplicador | Fórmula / Valor |
| :--- | :--- | :--- |
| **Indoor** | 0.5 | 3 XP por minuto (si > 5 min) |
| **Carrera (Run)** | 1.2 | `distanciaKm * 10 * 1.2` |
| **Ciclismo (Bike)** | 0.7 | `distanciaKm * 10 * 0.7` |
| **Caminata/Senderismo** | 0.9 | `distanciaKm * 10 * 0.9` |
| **Otros Exterior** | 1.0 | `distanciaKm * 10 * 1.0` |

#### B. XP Territorial
Premiamos la exploración y la defensa del dominio.

- **Nuevo Territorio (Conquista):** 8 XP (Máx. 50 celdas por actividad = 400 XP).
- **Territorio Defendido:** 3 XP por celda.
- **Territorio Reconquistado:** 12 XP por celda (premiamos recuperar lo perdido).

#### C. XP por Racha (Streak)
Se otorga un bono si la actividad mantiene la racha semanal activa (> 5 min).
- **Bono de Racha:** `10 XP * número de semanas de racha actual`.

#### D. XP por Récord Semanal
Si el usuario supera su mejor distancia semanal histórica:
- **Base Récord:** 30 XP.
- **Distancia Adicional:** 5 XP por cada bloque de 1 km superado del récord anterior.

---

## 2. Sistema de Territorios (The Grid)

El mundo está dividido en una rejilla global de celdas cuadradas.

### 2.1. Definición Técnica
- **Tamaño de Celda:** 0.002 grados (aprox. **222m x 222m**).
- **Identificación:** Cada celda tiene un ID único basado en sus coordenadas `(x, y)` en la rejilla.
- **Expiración:** Los territorios tienen una validez de **7 días** por defecto. Si el dueño no realiza una actividad que pase por esa celda en 7 días, el territorio queda libre (expira).

### 2.2. Tipos de Interacción
1.  **Conquista (Nueva):** Moverte por una celda que no tiene dueño o cuya propiedad ha expirado.
2.  **Defensa:** Pasar por una celda que ya te pertenece, renovando su tiempo de expiración.
3.  **Robo (Steal):** Pasar por una celda que pertenece a otro usuario activo. Te conviertes en el nuevo dueño y el anterior recibe una notificación de "Territorio Robado".
4.  **Reconquista:** Robar de vuelta una celda que te perteneció originalmente y fue robada por otro.

### 2.3. Sistema de Rivales
La app rastrea automáticamente las interacciones agresivas (robos):
- **Víctimas:** Lista de usuarios a los que has robado recientemente.
- **Ladrones:** Lista de usuarios que te han robado celdas.

---

## 3. Motor de Misiones (Mission Engine)

Las misiones son retos que se completan automáticamente al finalizar una actividad basándose en el desempeño.

### 3.1. Categorías y Rarezas
Categorías: `Territorial`, `Progresión`, `Esfuerzo Físico`.
Rarezas: `Común`, `Raro`, `Épico`, `Legendario`.

### 3.2. Lógica de Activación de Misiones

| Misión | Requisito | Rareza |
| :--- | :--- | :--- |
| **Exploración Inicial** | < 5 celdas nuevas | Común |
| **Expedición** | 5-14 celdas nuevas | Raro |
| **Conquista Épica** | 15-20 celdas nuevas | Épico |
| **Dominio Legendario** | > 20 celdas nuevas | Legendario |
| **Reconquista** | > 0 celdas reconquistadas | Épico |
| **Racha Activa** | Mantener racha (semana #X) | Raro / Épico (>=4 sem) |
| **Nuevo Récord Semanal** | Superar PB anterior | Épico / Legendario (>10km dif) |
| **Sprint Intenso** | Ritmo < 6:00 min/km (Run) | Raro |
| **Esfuerzo Destacado** | Ritmo alto según deporte | Común |

---

## 4. Procesos y Flujos de Datos

### 4.1. Flujo de Actividad (Orquestación)
1.  **Captura (App):** El usuario finaliza su entrenamiento.
2.  **Subida (App -> Firebase):** Se guarda el documento en la colección `activities`.
3.  **Procesado (Backend - Cloud Functions):**
    *   `processActivityTerritories`: Calcula las celdas atravesadas, identifica robos, defensas y conquistas.
    *   `GamificationService`: Calcula la XP basándose en el resultado territorial y el contexto del usuario.
    *   `MissionEngine`: Evalúa si se han cumplido misiones.
    *   **Actualización de Perfil:** Se suma la XP al usuario, se actualiza su nivel y sus estadísticas acumuladas.
4.  **Notificaciones:** Se disparan alertas push si hubo robos, victorias o logros.

### 4.2. Sistema de Notificaciones
- **Tipo "reaction":** Cuando alguien reacciona a un post en el feed social.
- **Tipo "territory_stolen":** Alertas inmediatas cuando pierdes control de una celda.
- **Tipo "achievement":** Al alcanzar hitos de nivel o misiones especiales.
- **Tipo "follower_activity":** Resumen de lo que hacen tus amigos.

---

## 5. Sistema de Insignias (Badges)

Existen retos estáticos que desbloquean insignias permanentes en el perfil del usuario.

| ID | Nombre | Requisito | Icono |
| :--- | :--- | :--- | :--- |
| `first_steps` | Primeros Pasos | Completar la primera actividad | figure.walk |
| `week_streak` | On Fire | Mantener racha de 1 semana | flame.fill |
| `explorer_novice` | Explorador Novel | Conquistar 10 celdas totales | map.fill |
| `marathoner` | Maratonista | Acumular 42 km totales | figure.run |
| `defensor` | Defensor | Recuperar un territorio perdido | shield.fill |

---

## 6. Rankings y Competencia

### 6.1. Ranking Semanal
Los usuarios compiten por XP acumulada en la semana actual.
- **Tendencias:** Se compara la posición actual con `previousRank` (instantánea del ranking anterior).
  - ↗️ **Sube:** Posición actual < Posición anterior.
  - ↘️ **Baja:** Posición actual > Posición anterior.
  - ➡️ **Neutral:** Sin cambios.

---

## 7. Arquitectura del Backend

- **Base de Datos:** Firestore (NoSQL).
- **Core Logic:** Escrito en TypeScript, ejecutado en Firebase Cloud Functions (V2).
- **Geofencing:** Implementado mediante una rejilla matemática personalizada (sin dependencias externas pesadas).
- **Sincronización:** La app observa los territorios locales mediante `snapshots` para una actualización en tiempo real en el mapa.

---
*Documento generado el 29 de diciembre de 2025.*
