import React from 'react';
import { Link } from 'react-router-dom';

const Footer = () => {
    return (
        <footer className="py-20 border-t border-white/5 bg-adventure-dark">
            <div className="max-w-7xl mx-auto px-6">
                <div className="flex flex-col md:flex-row items-center justify-between gap-10">
                    <div className="flex items-center gap-3 opacity-50">
                        <img src="/logo.jpg" alt="Logo" className="w-8 h-8 rounded-lg" />
                        <div className="font-bold tracking-widest uppercase text-xs">Adventure Streak</div>
                    </div>

                    <a
                        href="https://apps.apple.com/es/app/adventure-streak/id6755981465"
                        className="opacity-80 hover:opacity-100 transition-opacity"
                        aria-label="Descargar en el App Store"
                    >
                        <img
                            src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/es-es?releaseDate=1241395200"
                            alt="Consíguelo en el App Store"
                            className="h-8"
                        />
                    </a>

                    <div className="flex gap-8 text-xs font-bold uppercase tracking-widest text-white/30">
                        <Link to="/legal" className="hover:text-adventure-blue transition-colors">Privacidad</Link>
                        <Link to="/legal" className="hover:text-adventure-orange transition-colors">Términos</Link>
                        <a href="mailto:soporte@adventurestreak.app" className="hover:text-white transition-colors">Soporte</a>
                    </div>
                </div>

                <div className="mt-10 text-center">
                    <p className="text-white/10 text-[10px] uppercase tracking-[0.2em]">
                        © 2026 Adventure Streak. Todos los territorios reservados.
                    </p>
                </div>
            </div>
        </footer>
    );
};

export default Footer;
