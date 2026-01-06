import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
import HomeView from './views/HomeView';
import LegalView from './views/LegalView';
import MapView from './views/MapView';
import InviteView from './views/InviteView';


function App() {
    return (
        <Router>
            <div className="min-h-screen bg-adventure-dark flex flex-col">
                <Navbar />
                <div className="flex-1">
                    <Routes>
                        <Route path="/" element={<HomeView />} />
                        <Route path="/legal" element={<LegalView />} />
                        <Route path="/map" element={<MapView />} />
                        <Route path="/invite" element={<InviteView />} />
                        {/* Fallback to home for any other path (needed for Apple Review links if they are direct) */}
                        <Route path="*" element={<HomeView />} />
                    </Routes>
                </div>
                <Footer />
            </div>
        </Router>
    );
}

export default App;
