import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, query, orderBy, limit, onSnapshot } from "firebase/firestore";

function LiveFeed() {
    const [events, setEvents] = useState([]);
    const [error, setError] = useState(null);

    useEffect(() => {
        const q = query(
            collection(db, "feed"),
            orderBy("timestamp", "desc"),
            limit(10)
        );

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const feedEvents = snapshot.docs.map(doc => {
                const data = doc.data();
                return {
                    id: doc.id,
                    ...data,
                    timestamp: data.timestamp?.toDate() || new Date()
                };
            });
            setEvents(feedEvents);
            setError(null);
        }, (err) => {
            console.error("LiveFeed Error:", err);
            setError(err.message);
        });

        return () => unsubscribe();
    }, []);

    const getAnonymizedName = (level) => {
        if (level >= 30) return "Comandante Supremo";
        if (level >= 20) return "General de Élite";
        if (level >= 10) return "Explorador Veterano";
        if (level >= 5) return "Explorador";
        return "Recluta";
    };

    const formatRelativeTime = (date) => {
        const diffInSeconds = Math.floor((new Date() - date) / 1000);
        if (diffInSeconds < 60) return 'ahora mismo';
        if (diffInSeconds < 3600) return `hace ${Math.floor(diffInSeconds / 60)} min`;
        if (diffInSeconds < 86400) return `hace ${Math.floor(diffInSeconds / 3600)} h`;
        return `hace ${Math.floor(diffInSeconds / 86400)} d`;
    };

    const getIcon = (type) => {
        switch (type) {
            case 'territory_conquered': return '🚩';
            case 'distance_record': return '🏃';
            default: return '🛡️';
        }
    };

    // Placeholder data for when Firebase fails due to permissions or empty feed
    const placeholders = [
        { id: 'p1', type: 'territory_conquered', userLevel: 15, title: 'Un Capitán ha conquistado Madrid' },
        { id: 'p2', type: 'distance_record', userLevel: 5, title: 'Un Recluta ha superado su récord' },
        { id: 'p3', type: 'defended', userLevel: 40, title: 'Un General ha blindado su imperio' }
    ];

    const displayEvents = events.length > 0 ? events : placeholders;

    return (
        <div className="w-full bg-black/40 border-y border-white/5 py-3 overflow-hidden group">
            <div className="flex animate-infinite-scroll items-center gap-12 whitespace-nowrap min-w-full">
                {/* Doble renderizado para loop infinito suave */}
                {[...displayEvents, ...displayEvents, ...displayEvents].map((event, idx) => (
                    <div
                        key={`${event.id}-${idx}`}
                        className="flex items-center gap-4 px-2"
                    >
                        <span className="text-xl">{getIcon(event.type)}</span>
                        <div className="flex flex-col">
                            <div className="flex items-center gap-2">
                                <span className="text-white font-bold text-sm tracking-tight">
                                    {getAnonymizedName(event.userLevel || 1)}
                                </span>
                                {event.timestamp && (
                                    <span className="text-white/40 text-[10px] uppercase font-mono bg-white/5 px-1.5 py-0.5 rounded">
                                        {formatRelativeTime(event.timestamp)}
                                    </span>
                                )}
                            </div>
                            <p className="text-white/60 text-xs text-left">
                                {event.subtitle || event.title || "Actividad detectada"}
                            </p>
                        </div>
                        <div className="mx-4 w-1.5 h-1.5 rounded-full bg-adventure-blue/20" />
                    </div>
                ))}
            </div>
            {error && (
                <div className="absolute top-0 right-4 h-full flex items-center">
                    <span className="text-[8px] text-white/10 uppercase font-mono">Simulando frente...</span>
                </div>
            )}
        </div>
    );
}

export default LiveFeed;
