import React, { useEffect } from 'react';
import { useLocation } from 'react-router-dom';

const LegalView = () => {
    const { pathname } = useLocation();

    useEffect(() => {
        window.scrollTo(0, 0);
    }, [pathname]);

    return (
        <div className="min-h-screen bg-adventure-dark text-white font-sans selection:bg-adventure-blue/30 pt-32 pb-20 px-6">
            <div className="max-w-4xl mx-auto space-y-16">

                {/* Política de Privacidad */}
                <section className="glass-card p-8 md:p-12 border-white/10">
                    <h1 className="text-4xl font-bold mb-8 text-adventure-blue">Política de Privacidad</h1>
                    <div className="prose prose-invert max-w-none text-white/70 space-y-6">
                        <p className="text-sm italic">Última actualización: 29 de diciembre de 2024</p>
                        <p>En <strong>Adventure Streak</strong>, valoramos tu privacidad y nos comprometemos a proteger tus datos personales. Esta Política de Privacidad describe cómo recopilamos, utilizamos y compartimos tu información cuando utilizas nuestra aplicación móvil.</p>

                        <h2 className="text-2xl font-bold text-white mt-8">1. Información que Recopilamos</h2>
                        <h3 className="text-xl font-semibold text-white/90">1.1 Información proporcionada por el usuario</h3>
                        <ul className="list-disc pl-6 space-y-2">
                            <li><strong>Datos de Cuenta:</strong> Nombre, correo electrónico y foto de perfil (avatar).</li>
                            <li><strong>Contenido Social:</strong> Publicaciones, reacciones e interacciones con otros usuarios en el feed social.</li>
                        </ul>

                        <h3 className="text-xl font-semibold text-white/90">1.2 Datos de Salud y Actividad (HealthKit)</h3>
                        <p>Si otorgas permiso, Adventure Streak accede a datos de Apple Health (HealthKit) para:</p>
                        <ul className="list-disc pl-6 space-y-2">
                            <li>Importar entrenamientos (tipo de actividad, duración, distancia).</li>
                            <li>Sincronizar rutas de GPS asociadas a tus entrenamientos para la mecánica de conquista de territorios.</li>
                            <li>Calcular tu progreso, XP y niveles dentro de la aplicación.</li>
                        </ul>
                        <p className="italic text-sm text-adventure-orange">Nota: Los datos obtenidos de HealthKit no se utilizarán para fines publicitarios o de marketing.</p>

                        <h2 className="text-2xl font-bold text-white mt-8">2. Cómo Utilizamos tu Información</h2>
                        <p>Utilizamos la información recopilada para proporcionar las funcionalidades principales de la aplicación, gestionar tu perfil, facilitar la interacción social y mejorar la aplicación técnica.</p>
                    </div>
                </section>

                {/* Términos y Condiciones */}
                <section className="glass-card p-8 md:p-12 border-white/10">
                    <h1 className="text-4xl font-bold mb-8 text-adventure-orange">Términos y Condiciones</h1>
                    <div className="prose prose-invert max-w-none text-white/70 space-y-6">
                        <p className="text-sm italic">Última actualización: 29 de diciembre de 2024</p>
                        <p>Bienvenido a <strong>Adventure Streak</strong>. Al descargar o utilizar nuestra aplicación, aceptas cumplir con los siguientes términos y condiciones.</p>

                        <h2 className="text-2xl font-bold text-white mt-8">1. Uso de la Aplicación</h2>
                        <p>Adventure Streak es una plataforma de fitness y gamificación. Te comprometes a utilizar la aplicación de manera legal y ética.</p>

                        <h2 className="text-2xl font-bold text-white mt-8">2. Requisitos de Salud y Seguridad</h2>
                        <p className="bg-red-500/10 border border-red-500/20 p-4 rounded-xl text-red-200">
                            <strong>ADVERTENCIA IMPORTANTE:</strong> Al usar la aplicación, declaras que te encuentras en condiciones físicas adecuadas para realizar ejercicio. Consulta con un médico antes de comenzar.
                        </p>

                        <h2 className="text-2xl font-bold text-white mt-8">3. Derechos de Propiedad Intelectual</h2>
                        <p>Todo el software, diseño, logotipos y mecánicas de juego de Adventure Streak son propiedad intelectual de sus creadores.</p>
                    </div>
                </section>

                <div className="text-center pt-10">
                    <a href="/" className="text-adventure-blue hover:underline font-bold">← Volver al Inicio</a>
                </div>
            </div>
        </div>
    );
};

export default LegalView;
