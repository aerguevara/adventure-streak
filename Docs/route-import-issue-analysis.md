# Route import issue analysis

Context: HealthKit provides full GPS data, the workout is outdoor (hiking/walk), and the activity was not pre-existing in remote storage. One user’s import lacks GPS points and territory capture, while a parallel user’s identical activity imports correctly.

## Most likely causes
1. **HealthKit route attached to a different HKWorkout sample**
   - If the app links to a duplicated/merged workout without the `HKWorkoutRoute`, the import will treat it as a no-route activity even though HealthKit contains the track on another sample.

2. **Route chunks filtered out by validation**
   - Extremely slow pace, long pauses, or points with low horizontal accuracy can fail validation, producing an empty route after filtering.

3. **Unit mismatch or missing location permissions during background fetch**
   - If background import runs before location permissions are granted, the app may skip fetching `HKWorkoutRoute` even though the data is available; later foreground sync reuses the empty payload.

4. **Transient HealthKit query failure without retry**
   - A timeout or pagination error when reading the route could result in persisting the activity without points if there is no retry policy.

5. **Territory processing blocked by activity metadata**
   - Even when `isOutdoor` is true, malformed metadata (e.g., null `distance`, missing start/end timestamps) can prevent the territory pipeline from executing.

## Next diagnostic steps
- Inspect the exact `HKWorkout` identifier used on import and confirm it matches the sample that carries the `HKWorkoutRoute`.
- Log the number of points and max horizontal accuracy returned by the route query before filtering.
- Ensure background imports request `HKWorkoutRoute` only after location permission is confirmed, or trigger a re-fetch on next launch if route is missing.
- Add retry/alerting around route pagination errors so incomplete reads are retried before persisting.
- Capture metadata snapshot (type, distance, duration, start/end) for failing imports to spot anomalies that skip territory processing.
