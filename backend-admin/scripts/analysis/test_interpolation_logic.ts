/**
 * TEST GPS INTERPOLATION LOGIC
 * 
 * Validates the new logic that prevents filling "ghost territories" 
 * during large GPS jumps.
 */

const CELL_SIZE_DEGREES = 0.002;
const MAX_INTERPOLATION_DISTANCE_METERS = 300;

function getCellIndex(latitude: number, longitude: number): { x: number, y: number } {
    const x = Math.floor(longitude / CELL_SIZE_DEGREES);
    const y = Math.floor(latitude / CELL_SIZE_DEGREES);
    return { x, y };
}

function getCellId(x: number, y: number): string {
    return `${x}_${y}`;
}

function distanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371e3;
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
        Math.cos(φ1) * Math.cos(φ2) *
        Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

/**
 * REFIINED LOGIC (to be ported to territories.ts)
 */
function getCellsBetween(start: { latitude: number, longitude: number }, end: { latitude: number, longitude: number }): string[] {
    const cells = new Set<string>();
    const dist = distanceMeters(start.latitude, start.longitude, end.latitude, end.longitude);

    // Initial and final points always count
    const startIdx = getCellIndex(start.latitude, start.longitude);
    cells.add(getCellId(startIdx.x, startIdx.y));

    const endIdx = getCellIndex(end.latitude, end.longitude);
    cells.add(getCellId(endIdx.x, endIdx.y));

    if (dist < 10) {
        return Array.from(cells);
    }

    // --- NEW SECURITY THRESHOLD ---
    if (dist > MAX_INTERPOLATION_DISTANCE_METERS) {
        console.log(`   ⚠️  Salto de ${dist.toFixed(2)}m detectado (> ${MAX_INTERPOLATION_DISTANCE_METERS}m). Omitiendo relleno intermedio.`);
        return Array.from(cells);
    }
    // ------------------------------

    const stepSize = 20.0;
    const steps = Math.ceil(dist / stepSize);

    for (let i = 1; i < steps; i++) {
        const fraction = i / steps;
        const lat = start.latitude + (end.latitude - start.latitude) * fraction;
        const lon = start.longitude + (end.longitude - start.longitude) * fraction;

        const { x, y } = getCellIndex(lat, lon);
        cells.add(getCellId(x, y));
    }

    return Array.from(cells);
}

// --- RUN TESTS ---
console.log(`\n🧪 VALIDANDO LÓGICA DE INTERPOLACIÓN`);
console.log(`-----------------------------------`);

// Test 1: Segmento corto (Camiando normal)
const p1 = { latitude: 40.381, longitude: -3.655 };
const p2 = { latitude: 40.3813, longitude: -3.6553 }; // Aprox 50m
console.log(`Case 1: Segmento de ~50m (Caminando)`);
const res1 = getCellsBetween(p1, p2);
console.log(`   - Celdas resultantes: ${res1.length} (Esperado: > 1)`);

// Test 2: Salto medio (Corriendo/Bici)
const p3 = { latitude: 40.381, longitude: -3.655 };
const p4 = { latitude: 40.383, longitude: -3.657 }; // Aprox 280m
console.log(`\nCase 2: Salto de ~280m (Bicicleta/Señal intermitente)`);
const res2 = getCellsBetween(p3, p4);
console.log(`   - Celdas resultantes: ${res2.length} (Esperado: ~10-15)`);

// Test 3: Salto masivo (Teletransporte)
const p5 = { latitude: 40.381, longitude: -3.655 };
const p6 = { latitude: 40.381, longitude: -3.665 }; // Aprox 850m
console.log(`\nCase 3: Salto de ~850m (Anomalía detectada en 0F97...)`);
const res3 = getCellsBetween(p5, p6);
console.log(`   - Celdas resultantes: ${res3.length} (Esperado: 2 - solo los extremos)`);

if (res3.length === 2) {
    console.log(`\n✅ TEST PASADO: La lógica de protección bloqueó el relleno del salto masivo.`);
} else {
    console.log(`\n❌ TEST FALLIDO: Se generaron ${res3.length} celdas en el salto masivo.`);
}
console.log(`-----------------------------------\n`);
