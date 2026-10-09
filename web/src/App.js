import React, { useState, useEffect } from 'react';
import { AuthProvider, useAuth } from './context/AuthContext';
import Navbar from './components/Navbar';
import Login from './components/Login';
import UsuariosList from './components/UsuariosList';
import NonAdminPortal from './components/NonAdminPortal';
import MiCuenta from './components/MiCuenta';
import CrearMenu from './components/CrearMenu';
import Reportes from './components/Reportes';
import { UtensilsCrossed } from 'lucide-react';

function AppContent() {
  const { user, isAdmin, loading, role } = useAuth();
  const [activeTab, setActiveTab] = useState('usuarios');

  // Adjust active tab when authentication state or role changes
  useEffect(() => {
    if (user) {
      if (isAdmin) {
        setActiveTab('usuarios');
      } else {
        setActiveTab('portal');
      }
    }
  }, [user, isAdmin]);

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-900 flex flex-col items-center justify-center p-4 text-white">
        <div className="w-16 h-16 rounded-2xl bg-blue-600/20 border border-blue-500/40 flex items-center justify-center mb-4 animate-pulse">
          <UtensilsCrossed className="w-8 h-8 text-blue-400" />
        </div>
        <div className="w-8 h-8 border-3 border-blue-500 border-t-transparent rounded-full animate-spin mb-3" />
        <p className="text-sm font-medium text-slate-400">Iniciando Restaurante Gourmet...</p>
      </div>
    );
  }

  // Not logged in -> Show Login view
  if (!user) {
    return <Login />;
  }

  // Logged in -> Render Top Navbar + View according to activeTab and role permissions
  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
      <Navbar activeTab={activeTab} setActiveTab={setActiveTab} />

      <main className="flex-1 pb-12">
        {activeTab === 'usuarios' && (
          isAdmin ? (
            <UsuariosList />
          ) : (
            <NonAdminPortal setActiveTab={setActiveTab} />
          )
        )}

        {activeTab === 'portal' && <NonAdminPortal setActiveTab={setActiveTab} />}
        {activeTab === 'cuenta' && <MiCuenta />}
        {activeTab === 'menu' && <CrearMenu />}
        {activeTab === 'reportes' && <Reportes />}
      </main>

      {/* Footer */}
      <footer className="bg-white border-t border-slate-200 py-4 text-center text-xs text-slate-400">
        <p>© 2026 Restaurante Gourmet - Sistema de Gestión Institucional</p>
      </footer>
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}
