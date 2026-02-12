import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, query, orderBy, limit, onSnapshot, doc } from "firebase/firestore";
import { Link } from 'react-router-dom';
import LiveFeed from '../components/LiveFeed';
import MapSnippet from '../components/MapSnippet';

function HomeView() {
    const [rankingData, setRankingData] = useState([]);
    const [loading, setLoading] = useState(true);
    const [seasonInfo, setSeasonInfo] = useState({
        name: "Nueva Temporada",
        subtitle: "Enero 2026"
    });

    useEffect(() => {
        const q = query(
            collection(db, "users"),
            orderBy("xp", "desc"),
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

    useEffect(() => {
        const docRef = doc(db, "config", "gameplay");
        const unsubscribe = onSnapshot(docRef, (docSnap) => {
            if (docSnap.exists()) {
                const data = docSnap.data();
                setSeasonInfo({
                    name: data.currentSeasonName || "Nueva Temporada",
                    subtitle: data.currentSeasonSubtitle || "T1 2026"
                });
            }
        });
        return () => unsubscribe();
    }, []);

    return (
        <div className="min-h-screen bg-adventure-dark text-white font-sans selection:bg-adventure-blue/30 scroll-smooth">
            <main className="pt-20">
                {/* Live Activity Feed */}
                <div className="w-full bg-adventure-dark/80 backdrop-blur-md border-b border-white/5 relative z-30">
                    <LiveFeed />
                </div>

                {/* Hero Section */}
                <section className="relative pt-32 pb-20 px-6 overflow-hidden">
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
                            {seasonInfo.name} - {seasonInfo.subtitle}
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
                                href="https://apps.apple.com/es/app/adventure-streak/id6755981465"
                                className="transition-transform hover:scale-105 active:scale-95"
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
                <section id="features" className="max-w-7xl mx-auto px-6 py-12">
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

                {/* Map Preview Section */}
                <section className="max-w-7xl mx-auto px-6 py-20 border-t border-white/5">
                    <div className="glass-card overflow-hidden bg-black/40 border-white/5 relative group">
                        <div className="p-12 md:p-20 flex flex-col md:flex-row items-center gap-12">
                            <div className="flex-1 text-center md:text-left">
                                <h2 className="text-4xl md:text-5xl font-bold mb-6">Explora el Mapa de Guerra</h2>
                                <p className="text-white/40 text-lg mb-8">
                                    Visualiza los territorios conquistados en tiempo real. ¿Quién domina tu barrio hoy?
                                </p>
                                <Link
                                    to="/map"
                                    className="inline-flex items-center gap-4 bg-white text-black px-8 py-4 rounded-full font-bold hover:bg-adventure-blue hover:text-white transition-all active:scale-95 shadow-[0_0_20px_rgba(255,255,255,0.1)] hover:shadow-adventure-blue/20"
                                >
                                    <span>Ver Mapa Global</span>
                                    <span className="text-xl">🗺️</span>
                                </Link>
                            </div>
                            <div className="flex-1 relative min-h-[400px] w-full group-hover:scale-[1.02] transition-transform duration-700">
                                <MapSnippet />
                            </div>
                        </div>
                    </div>
                </section>

                {/* Detailed Ranking Section */}
                <section id="ranking" className="max-w-7xl mx-auto px-6 py-20 pb-40">
                    <div className="text-center mb-16">
                        <h2 className="text-4xl font-bold mb-4">Clasificación Global</h2>
                        <p className="text-white/40">Domina las celdas y escala posiciones con tus conquistas.</p>
                    </div>

                    <div className="glass-card overflow-x-auto ring-1 ring-white/5 shadow-2xl">
                        <div className="min-w-[1000px]">
                            <div className="p-6 bg-white/5 border-b border-white/5 flex items-center text-xs font-bold uppercase tracking-widest text-white/30">
                                <span className="w-16 pl-4 text-center">Rk</span>
                                <span className="flex-1 text-left">Explorador</span>
                                <div className="flex gap-10 items-center text-right pr-8">
                                    <span className="w-20">Nivel / XP</span>
                                    <span className="w-24 text-adventure-blue">Mapa (Celdas)</span>
                                    <span className="w-24">Km GPS</span>
                                    <span className="w-16 text-emerald-400">Nuevos</span>
                                    <span className="w-16 text-red-400">Robados</span>
                                </div>
                            </div>

                            <div className="divide-y divide-white/5 min-h-[400px]">
                                {loading ? (
                                    <div className="flex items-center justify-center h-64 opacity-20 animate-pulse">
                                        Cargando clasificación...
                                    </div>
                                ) : (
                                    rankingData.map((user) => (
                                        <div key={user.rank} className={`p-6 flex items-center hover:bg-white/[0.02] transition-colors ${user.rank <= 3 ? 'bg-white/[0.01]' : ''}`}>
                                            <div className="w-16 flex justify-center">
                                                {user.rank === 1 ? (
                                                    <span className="text-3xl drop-shadow-[0_0_10px_rgba(255,165,0,0.5)]">🥇</span>
                                                ) : user.rank === 2 ? (
                                                    <span className="text-2xl text-slate-400">🥈</span>
                                                ) : user.rank === 3 ? (
                                                    <span className="text-2xl text-amber-700">🥉</span>
                                                ) : (
                                                    <span className="font-mono text-white/20">{user.rank}</span>
                                                )}
                                            </div>
                                            <div className="flex-1 flex items-center gap-4">
                                                <div className={`w-12 h-12 rounded-full overflow-hidden flex items-center justify-center text-xl border-2 ${user.rank === 1 ? 'border-adventure-orange' : 'border-white/5'}`}>
                                                    {user.avatar.startsWith('http') ? (
                                                        <img src={user.avatar} alt="" className="w-full h-full object-cover" />
                                                    ) : (
                                                        user.avatar
                                                    )}
                                                </div>
                                                <div className="flex flex-col text-left">
                                                    <span className={`font-bold text-lg ${user.rank === 1 ? 'text-adventure-orange' : ''}`}>{user.name}</span>
                                                    <span className="text-[10px] text-white/20 uppercase font-mono tracking-wider">
                                                        {user.rank === 1 ? 'Gran Conquistador' : user.level > 10 ? 'Explorador Veterano' : 'Aventurero'}
                                                    </span>
                                                </div>
                                            </div>

                                            <div className="flex gap-10 items-center text-right pr-8">
                                                <div className="w-20 flex flex-col items-end">
                                                    <span className="font-bold text-adventure-blue">Lvl {user.level}</span>
                                                    <span className="text-[10px] text-white/30 tracking-tighter">{user.xp.toLocaleString()} XP</span>
                                                </div>
                                                <div className="w-24 flex flex-col items-end">
                                                    <span className="bg-adventure-blue/10 text-adventure-blue px-3 py-1 rounded-full text-sm font-bold border border-adventure-blue/20">{user.cells}</span>
                                                    <span className="text-[9px] text-white/20 mt-1 uppercase tracking-tighter font-medium text-center">Celdas</span>
                                                </div>
                                                <span className="w-24 font-mono text-sm text-white/60">{user.km.toFixed(1)} km</span>
                                                <span className="w-16 font-bold text-emerald-400/60">{user.conquered}</span>
                                                <span className="w-16 font-bold text-red-400/60">{user.stolen}</span>
                                            </div>
                                        </div>
                                    ))
                                )}
                            </div>
                        </div>
                    </div>
                </section>
            </main>

            {/* Floating CTA */}
            <div className="fixed bottom-8 left-1/2 -translate-x-1/2 z-50 flex items-center gap-4 animate-in fade-in slide-in-from-bottom-10 duration-1000">
                <a
                    href="https://apps.apple.com/es/app/adventure-streak/id6755981465"
                    className="flex items-center gap-3 bg-white text-black px-8 py-4 rounded-2xl font-bold shadow-2xl hover:bg-adventure-blue hover:text-white transition-all transform hover:scale-105 active:scale-95 group"
                >
                    <span>Únete a la Conquista</span>
                    <span className="text-xl group-hover:translate-x-1 transition-transform">→</span>
                </a>
            </div>
        </div>
    );
}

export default HomeView;
