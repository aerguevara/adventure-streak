import React, { useState } from 'react';
import { useSearchParams } from 'react-router-dom';

const InviteView = () => {
    const [searchParams] = useSearchParams();
    const token = searchParams.get('token');
    const [copied, setCopied] = useState(false);

    const handleCopy = () => {
        if (token) {
            navigator.clipboard.writeText(token);
            setCopied(true);
            setTimeout(() => setCopied(false), 2000);
        }
    };

    return (
        <div className="relative min-h-screen pt-20 pb-12 flex flex-col items-center justify-center overflow-hidden">
            {/* Background Gradients */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-5xl h-full pointer-events-none -z-10">
                <div className="absolute top-[-20%] left-[-10%] w-[60%] h-[80%] bg-adventure-blue/20 blur-[120px] rounded-full animate-pulse" />
                <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[70%] bg-adventure-orange/10 blur-[100px] rounded-full" />
            </div>

            <div className="container mx-auto px-4 text-center max-w-2xl z-10">
                <div className="mb-8 flex justify-center">
                    <div className="w-24 h-24 bg-gradient-to-br from-adventure-primary to-adventure-secondary rounded-3xl flex items-center justify-center shadow-lg transform rotate-3 hover:rotate-6 transition-transform duration-300">
                        <span className="text-5xl">✉️</span>
                    </div>
                </div>

                <h1 className="text-4xl md:text-5xl font-bold mb-6 bg-gradient-to-r from-white to-gray-400 bg-clip-text text-transparent">
                    ¡Has sido invitado!
                </h1>

                <p className="text-xl text-gray-300 mb-8 leading-relaxed">
                    Alguien te ha enviado un pase exclusivo para unirte a
                    <span className="font-bold text-adventure-primary"> Adventure Streak</span>.
                    <br />
                    Copia tu código y descarga la app.
                </p>

                {token && (
                    <div className="mb-10 flex flex-col items-center space-y-4">
                        <div className="p-4 bg-white/5 backdrop-blur-md rounded-xl border border-white/10 inline-block min-w-[200px]">
                            <p className="text-sm text-gray-400 mb-1 uppercase tracking-wider">Tu Código de Acceso</p>
                            <code className="text-2xl font-mono text-adventure-primary font-bold tracking-widest block mb-2">
                                {token}
                            </code>
                        </div>

                        <button
                            onClick={handleCopy}
                            className={`px-6 py-2 rounded-full text-sm font-semibold transition-all duration-200 flex items-center ${copied
                                ? 'bg-green-500/20 text-green-400 border border-green-500/50'
                                : 'bg-white/10 text-white hover:bg-white/20 border border-white/10'
                                }`}
                        >
                            {copied ? (
                                <>
                                    <span className="mr-2">✓</span> ¡Copiado!
                                </>
                            ) : (
                                <>
                                    <span className="mr-2">📋</span> Copiar Código
                                </>
                            )}
                        </button>
                    </div>
                )}

                <div className="space-y-4">
                    <a
                        href="https://apps.apple.com/app/id6739666060"
                        className="transition-transform hover:scale-105 inline-block"
                        aria-label="Descargar en el App Store"
                    >
                        <img
                            src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/es-es?releaseDate=1241395200"
                            alt="Consíguelo en el App Store"
                            className="h-16"
                        />
                    </a>

                    <p className="text-sm text-gray-500 mt-4">
                        Solo disponible para iOS
                    </p>
                </div>
            </div>
        </div>
    );
};

export default InviteView;
