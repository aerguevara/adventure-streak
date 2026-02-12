import React from 'react';
import { Link, useLocation } from 'react-router-dom';

const Navbar = () => {
    const location = useLocation();
    const isHome = location.pathname === '/';

    return (
        <nav className="fixed top-0 w-full z-50 bg-adventure-dark/80 backdrop-blur-md border-b border-white/5">
            <div className="max-w-7xl mx-auto px-6 h-20 flex items-center justify-between">
                <Link to="/" className="flex items-center gap-3 active:scale-95 transition-transform">
                    <div className="w-10 h-10 overflow-hidden rounded-xl shadow-lg shadow-adventure-blue/20 bg-white/5 border border-white/10">
                        <img src="/logo.jpg" alt="Logo" className="w-full h-full object-cover"
                            onError={(e) => {
                                e.target.src = "https://firebasestorage.googleapis.com/v0/b/adventure-streak.firebasestorage.app/o/app_icon.png?alt=media";
                            }}
                        />
                    </div>
                    <span className="text-xl font-bold tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-white to-white/60">Adventure Streak</span>
                </Link>
                <div className="flex items-center gap-4 md:gap-8">
                    <div className="hidden md:flex items-center gap-8 text-sm font-semibold text-white/60">
                        <Link to="/map" className="hover:text-adventure-blue transition-colors flex items-center gap-2">
                            <span>🌍</span> Mapa
                        </Link>
                        {!isHome && (
                            <Link to="/" className="hover:text-white transition-colors">Inicio</Link>
                        )}
                    </div>
                    <a
                        href="https://apps.apple.com/es/app/adventure-streak/id6755981465"
                        className="bg-white text-black px-4 py-2 rounded-xl text-xs md:text-sm font-bold hover:bg-adventure-blue hover:text-white transition-all active:scale-95"
                    >
                        Descargar App
                    </a>
                </div>
            </div>
        </nav>
    );
};

export default Navbar;
