import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, query, orderBy, limit, onSnapshot } from "firebase/firestore";
import { Link } from 'react-router-dom';

function HomeView() {
    const [rankingData, setRankingData] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const q = query(
            collection(db, "users"),
            orderBy("level", "desc"),
            limit(20)
        );

        const unsubscribe = onSnapshot(q, (querySnapshot) => {
            const users = [];
            let rank = 1;
            querySnapshot.forEach((doc) => {
                const data = doc.data();
                users.push({
                    rank: rank++,
                    name: data.displayName || "Explorador Anónimo",
                    level: data.level || 1,
                    xp: data.xp || 0,
                    km: data.totalDistanceKm || 0,
                    cells: data.totalCellsOwned || 0,
                    conquered: data.totalConqueredTerritories || 0,
                    stolen: data.totalStolenTerritories || 0,
                    defended: data.totalDefendedTerritories || 0,
                    recaptured: data.totalRecapturedTerritories || 0,
                    avatar: data.avatarURL || (rank % 2 === 0 ? "🏔️" : "🏃")
                });
            });
            setRankingData(users);
            setLoading(false);
        });

        return () => unsubscribe();
    }, []);

    const scrollToRanking = () => {
        document.getElementById('ranking')?.scrollIntoView({ behavior: 'smooth' });
    };

    return (
        <div className="min-h-screen bg-adventure-dark text-white font-sans selection:bg-adventure-blue/30 scroll-smooth">
            <main>
                {/* Hero Section */}
                <section className="relative pt-40 pb-20 px-6 overflow-hidden">
                    <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-5xl h-full pointer-events-none">
                        <div className="absolute top-[-20%] left-[-10%] w-[60%] h-[80%] bg-adventure-blue/20 blur-[120px] rounded-full animate-pulse" />
                        <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[70%] bg-adventure-orange/10 blur-[100px] rounded-full" />
                    </div>

                    <div className="max-w-4xl mx-auto text-center relative z-10">
                        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/5 border border-white/10 text-adventure-blue text-xs font-bold uppercase tracking-wider mb-8">
                            <span className="relative flex h-2 w-2">
                                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-adventure-blue opacity-75"></span>
                                <span className="relative inline-flex rounded-full h-2 w-2 bg-adventure-blue"></span>
                            </span>
                            Próxima Temporada Disponible
                        </div>
                        <h1 className="text-5xl md:text-7xl font-bold mb-8 leading-[1.1] tracking-tight">
                            Domina tu ciudad.<br />
                            <span className="text-transparent bg-clip-text bg-gradient-to-r from-adventure-blue to-adventure-orange">
                                Marca tu territorio.
                            </span>
                        </h1>
                        <p className="text-xl text-white/50 mb-12 max-w-2xl mx-auto leading-relaxed">
                            Convierte tus entrenamientos en una conquista global. Cada kilómetro cuenta para expandir tu imperio y desafiar a otros aventureros.
                        </p>
                        <div className="flex flex-col sm:flex-row items-center justify-center gap-6">
                            <a
                                href="#"
                                className="transition-transform hover:scale-105"
                                aria-label="Descargar en el App Store"
                            >
                                <img
                                    src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/es-es?releaseDate=1241395200"
                                    alt="Consíguelo en el App Store"
                                    className="h-16"
                                />
                            </a>

                        </div>
                    </div>
                </section>

                {/* Features Section */}
                <section id="features" className="max-w-7xl mx-auto px-6 py-24 border-t border-white/5">
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-12">
                        <div className="glass-card p-10 hover:border-adventure-blue/40 transition-colors group">
                            <div className="w-14 h-14 bg-adventure-blue/10 rounded-2xl flex items-center justify-center mb-8 group-hover:scale-110 transition-transform">
                                <span className="text-3xl">🗺️</span>
                            </div>
                            <h3 className="text-2xl font-bold mb-4">Domina el Mapa</h3>
                            <p className="text-white/40 leading-relaxed">
                                Cada paso que das en la vida real se traduce en territorio conquistado. Convierte tu ciudad en tu zona de juego.
                            </p>
                        </div>
                        <div className="glass-card p-10 hover:border-adventure-orange/40 transition-colors group">
                            <div className="w-14 h-14 bg-adventure-orange/10 rounded-2xl flex items-center justify-center mb-8 group-hover:scale-110 transition-transform">
                                <span className="text-3xl">⚔️</span>
                            </div>
                            <h3 className="text-2xl font-bold mb-4">Combate Estratégico</h3>
                            <p className="text-white/40 leading-relaxed">
                                No solo conquistas, también debes defender. Otros aventureros intentarán robar tus territorios cada día.
                            </p>
                        </div>
                        <div className="glass-card p-10 hover:border-emerald-500/40 transition-colors group">
                            <div className="w-14 h-14 bg-emerald-500/10 rounded-2xl flex items-center justify-center mb-8 group-hover:scale-110 transition-transform">
                                <span className="text-3xl">📈</span>
                            </div>
                            <h3 className="text-2xl font-bold mb-4">Progresión Élite</h3>
                            <p className="text-white/40 leading-relaxed">
                                Gana XP, sube de nivel y desbloquea insignias exclusivas. Tu esfuerzo físico tiene recompensa tangible.
                            </p>
                        </div>
                    </div>
                </section>

                {/* Detailed Ranking Section */}
                <section id="ranking" className="max-w-7xl mx-auto px-6 py-20">
                    <div className="text-center mb-16">
                        <h2 className="text-4xl font-bold mb-4">Clasificación Global</h2>
                        <p className="text-white/40">Domina las celdas y escala posiciones con tus conquistas.</p>
                    </div>

                    <div className="glass-card overflow-x-auto overflow-y-hidden">
                        <div className="min-w-[1000px]">
                            <div className="p-6 bg-white/5 border-b border-white/5 flex items-center text-xs font-bold uppercase tracking-widest text-white/30">
                                <span className="w-12">Rk</span>
                                <span className="flex-1">Explorador</span>
                                <div className="flex gap-10 items-center text-right pr-4">
                                    <span className="w-20">Nivel / XP</span>
                                    <span className="w-24 text-adventure-blue">Mapa (Celdas)</span>
                                    <span className="w-24">Km GPS</span>
                                    <span className="w-16 text-emerald-400">Nuevos</span>
                                    <span className="w-16 text-red-400">Robados</span>
                                    <span className="w-16 text-orange-400">Defend.</span>
                                    <span className="w-16 text-purple-400">Recup.</span>
                                </div>
                            </div>

                            <div className="divide-y divide-white/5 min-h-[400px]">
                                {loading ? (
                                    <div className="flex items-center justify-center h-64 opacity-20 animate-pulse">
                                        Cargando clasificación...
                                    </div>
                                ) : (
                                    rankingData.map((user) => (
                                        <div key={user.rank} className="p-6 flex items-center hover:bg-white/[0.02] transition-colors">
                                            <span className={`w-12 font-bold ${user.rank === 1 ? 'text-adventure-orange' : user.rank <= 3 ? 'text-adventure-blue' : 'text-white/30'}`}>
                                                {user.rank}
                                            </span>
                                            <div className="flex-1 flex items-center gap-4">
                                                <div className="w-10 h-10 bg-white/5 rounded-full overflow-hidden flex items-center justify-center text-xl">
                                                    {user.avatar.startsWith('http') ? (
                                                        <img src={user.avatar} alt="" className="w-full h-full object-cover" />
                                                    ) : (
                                                        user.avatar
                                                    )}
                                                </div>
                                                <div className="flex flex-col">
                                                    <span className="font-bold">{user.name}</span>
                                                    <span className="text-[10px] text-white/20 uppercase font-mono tracking-tighter">Explorador de Élite</span>
                                                </div>
                                            </div>

                                            <div className="flex gap-10 items-center text-right pr-4">
                                                <div className="w-20 flex flex-col items-end">
                                                    <span className="font-semibold text-adventure-blue">Lvl {user.level}</span>
                                                    <span className="text-[10px] text-white/40">{user.xp} XP</span>
                                                </div>
                                                <div className="w-24 flex flex-col items-end">
                                                    <span className="bg-adventure-blue/10 text-adventure-blue px-2 py-1 rounded text-sm font-bold">{user.cells}</span>
                                                    <span className="text-[9px] text-white/20 mt-1 uppercase tracking-tighter italic">Celdas Totales</span>
                                                </div>
                                                <span className="w-24 font-mono text-sm">{user.km.toFixed(1)} km</span>
                                                <span className="w-16 font-bold text-emerald-400/80">{user.conquered}</span>
                                                <span className="w-16 font-bold text-red-400/80">{user.stolen}</span>
                                                <span className="w-16 font-bold text-orange-400/80">{user.defended}</span>
                                                <span className="w-16 font-bold text-purple-400/80">{user.recaptured}</span>
                                            </div>
                                        </div>
                                    ))
                                )}
                            </div>
                        </div>
                    </div>

                    <div className="mt-8 p-6 glass-card bg-adventure-blue/5 border-adventure-blue/20">
                        <h4 className="text-adventure-blue font-bold mb-2 flex items-center gap-2">
                            ℹ️ ¿Qué significan estas métricas?
                        </h4>
                        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 text-xs text-white/40">
                            <p><strong className="text-white/60">Mapa (Celdas):</strong> El recuento total de territorios que posees actualmente en el mapa global.</p>
                            <p><strong className="text-white/60">Nuevos:</strong> Celdas conquistadas que no pertenecían a ningún otro jugador anteriormente.</p>
                            <p><strong className="text-white/60">Robados:</strong> Celdas que has arrebatado a otros jugadores mediante tus incursiones.</p>
                            <p><strong className="text-white/60">Defendidos:</strong> Intentos de robo que has bloqueado manteniendo tu racha o nivel.</p>
                            <p><strong className="text-white/60">Recuperados:</strong> Celdas que te habían robado y has vuelto a reclamar para tu imperio.</p>
                        </div>
                    </div>
                </section>
            </main>
        </div>
    );
}

export default HomeView;
