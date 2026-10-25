import React, { useState, useEffect } from 'react';
import { AuthProvider, useAuth } from './context/AuthContext';
import Navbar from './components/Navbar';
import Login from './components/Login';
import UsuariosList from './components/UsuariosList';
import NonAdminPortal from './components/NonAdminPortal';
import MiCuenta from './components/MiCuenta';
import CrearMenu from './components/CrearMenu';
import Reportes from './components/Reportes';
import CalendarioSection from './components/calendario/CalendarioSection';
import { UtensilsCrossed } from 'lucide-react';

function AppContent() {
  const { user, isAdmin, loading, role } = useAuth();

  // Persistir la pestaña activa en localStorage para que no se pierda al cambiar de pestaña en el navegador
  const [activeTab, setActiveTabState] = useState(() => {
    return localStorage.getItem('restaurante_active_tab') || 'usuarios';
  });

  const setActiveTab = (tab) => {
    setActiveTabState(tab);
    localStorage.setItem('restaurante_active_tab', tab);
  };

  // Ajustar la pestaña SOLO cuando cambie la autenticación o rol, respetando la pestaña previamente guardada
  useEffect(() => {
    if (user) {
      const savedTab = localStorage.getItem('restaurante_active_tab');
      if (!isAdmin) {
        // Para roles no administradores, proteger pestañas administrativas
        const adminTabs = ['usuarios', 'reportes'];
        if (!savedTab || adminTabs.includes(savedTab)) {
          setActiveTab('portal');
        } else {
          setActiveTabState(savedTab);
        }
      } else {
        // Para administradores, si estaba en portal de empleado, ir a usuarios
        if (savedTab === 'portal') {
          setActiveTab('usuarios');
        } else if (savedTab) {
          setActiveTabState(savedTab);
        }
      }
    }
  }, [user?.id, isAdmin]);

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-900 flex flex-col items-center justify-center p-4 text-white">
        <div className="w-16 h-16 rounded-2xl bg-blue-600/20 border border-blue-500/40 flex items-center justify-center mb-4 animate-pulse">
          <UtensilsCrossed className="w-8 h-8 text-blue-400" />
        </div>
        <div className="w-8 h-8 border-3 border-blue-500 border-t-transparent rounded-full animate-spin mb-3" />
        <p className="text-sm font-medium text-slate-400">Iniciando Restaurante Cielo...</p>
      </div>
    );
  }

  // Not logged in -> Show Login view
  if (!user) {
    return <Login />;
  }

  // Logged in -> Render Top Navbar + View according to activeTab and role permissions
  return (
    <div className="min-h-screen w-screen bg-slate-50 flex flex-col">
      <Navbar activeTab={activeTab} setActiveTab={setActiveTab} />

      <main className="flex-1 pb-16">
        {activeTab === 'usuarios' && (
          isAdmin ? (
            <UsuariosList />
          ) : (
            <NonAdminPortal setActiveTab={setActiveTab} />
          )
        )}

        {activeTab === 'portal' && <NonAdminPortal setActiveTab={setActiveTab} />}
        {activeTab === 'calendario' && <CalendarioSection />}
        {activeTab === 'cuenta' && <MiCuenta />}
        {activeTab === 'menu' && <CrearMenu />}
        {activeTab === 'reportes' && <Reportes />}
      </main>

      {/* Footer */}
      <footer className="bg-white border-t border-slate-200 py-4 text-center text-xs text-slate-400">
        <p>© 2026 Restaurante Cielo</p>
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
