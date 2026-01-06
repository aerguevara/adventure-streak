/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            colors: {
                'adventure-blue': '#4C6FFF',
                'adventure-orange': '#FF8A00',
                'adventure-dark': '#0A0A0B',
                'adventure-gray': '#1C1C1E',
            },
            backgroundImage: {
                'glass': 'linear-gradient(135deg, rgba(255, 255, 255, 0.1), rgba(255, 255, 255, 0.05))',
            }
        },
    },
    plugins: [],
}
