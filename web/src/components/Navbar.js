import React from 'react';
import { useAuth } from '../context/AuthContext';
import { 
  Users, 
  UserCheck, 
  UtensilsCrossed, 
  BarChart3, 
  LogOut, 
  ShieldCheck, 
  Sparkles,
  Layers
} from 'lucide-react';

export default function Navbar({ activeTab, setActiveTab }) {
  const { user, profile, role, isAdmin, logout } = useAuth();

  const getRoleBadgeColor = (r) => {
    switch (r) {
      case 'Administrador':
        return 'bg-purple-100 text-purple-800 border-purple-200';
      case 'Empleado':
        return 'bg-emerald-100 text-emerald-800 border-emerald-200';
      case 'Institucion':
        return 'bg-amber-100 text-amber-800 border-amber-200';
      default:
        return 'bg-blue-100 text-blue-800 border-blue-200';
    }
  };

  const navItems = isAdmin
    ? [
        { id: 'usuarios', label: 'Usuarios', icon: Users, badge: 'Admin' },
        { id: 'cuenta', label: 'Mi Cuenta', icon: UserCheck },
        { id: 'menu', label: 'Crear Menú', icon: UtensilsCrossed },
        { id: 'reportes', label: 'Reportes', icon: BarChart3 },
      ]
    : [
        { id: 'portal', label: 'Mi Panel', icon: Layers },
        { id: 'cuenta', label: 'Mi Cuenta', icon: UserCheck },
        { id: 'menu', label: 'Ver Menú', icon: UtensilsCrossed },
      ];

  const displayName = profile?.nombres
    ? `${profile.nombres} ${profile.apellidos || ''}`
    : user?.email?.split('@')[0] || 'Usuario';

  return (
    <header className="sticky top-0 z-40 bg-gradient-to-r from-blue-700 via-blue-600 to-indigo-700 text-white shadow-lg border-b border-blue-500/30">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Brand / Logo */}
          <div className="flex items-center space-x-3 cursor-pointer" onClick={() => setActiveTab(isAdmin ? 'usuarios' : 'portal')}>
            <div className="w-10 h-10 rounded-xl bg-white/15 backdrop-blur-md flex items-center justify-center shadow-inner border border-white/20">
              <UtensilsCrossed className="w-5 h-5 text-white" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <span className="font-bold text-lg tracking-tight">Restaurante Cielo</span>
                <span className="hidden sm:inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-500/40 text-blue-100 border border-blue-400/30">
                  <Sparkles className="w-3 h-3 mr-1 text-yellow-300" /> Sistema
                </span>
              </div>
              <p className="text-xs text-blue-100/80 -mt-0.5">Gestión Institucional</p>
            </div>
          </div>

          {/* Navigation links */}
          <nav className="hidden md:flex items-center space-x-1">
            {navItems.map((item) => {
              const Icon = item.icon;
              const isActive = activeTab === item.id;
              return (
                <button
                  key={item.id}
                  onClick={() => setActiveTab(item.id)}
                  className={`flex items-center space-x-2 px-3.5 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
                    isActive
                      ? 'bg-white text-blue-700 shadow-md transform scale-[1.02]'
                      : 'text-blue-50 hover:bg-white/10 hover:text-white'
                  }`}
                >
                  <Icon className={`w-4 h-4 ${isActive ? 'text-blue-600' : 'text-blue-200'}`} />
                  <span>{item.label}</span>
                  {item.badge && (
                    <span className={`text-[10px] uppercase font-bold px-1.5 py-0.5 rounded-full ${
                      isActive ? 'bg-blue-100 text-blue-700' : 'bg-white/20 text-white'
                    }`}>
                      {item.badge}
                    </span>
                  )}
                </button>
              );
            })}
          </nav>

          {/* User profile info & logout */}
          <div className="flex items-center space-x-3">
            <div className="hidden lg:flex items-center space-x-2.5 bg-black/15 px-3 py-1.5 rounded-xl border border-white/10">
              <div className="w-7 h-7 rounded-full bg-blue-100 text-blue-700 font-bold text-xs flex items-center justify-center shadow-sm">
                {displayName.charAt(0).toUpperCase()}
              </div>
              <div className="text-left">
                <p className="text-xs font-semibold leading-tight truncate max-w-[120px]">{displayName}</p>
                <div className="flex items-center space-x-1">
                  <span className={`text-[10px] font-medium px-1.5 py-0.2 rounded-full border ${getRoleBadgeColor(role)}`}>
                    {role}
                  </span>
                </div>
              </div>
            </div>

            <button
              onClick={logout}
              className="flex items-center space-x-1.5 bg-rose-500/20 hover:bg-rose-500/30 text-rose-100 hover:text-white border border-rose-400/30 px-3 py-2 rounded-lg text-xs font-medium transition-all duration-200 hover:shadow"
              title="Cerrar Sesión"
            >
              <LogOut className="w-4 h-4" />
              <span className="hidden sm:inline">Cerrar Sesión</span>
            </button>
          </div>
        </div>

        {/* Mobile Navigation Row */}
        <div className="flex md:hidden items-center justify-around py-2 border-t border-white/10 overflow-x-auto">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setActiveTab(item.id)}
                className={`flex flex-col items-center py-1 px-3 rounded-md text-xs font-medium ${
                  isActive ? 'text-white font-bold bg-white/20' : 'text-blue-100/80 hover:text-white'
                }`}
              >
                <Icon className="w-4 h-4 mb-0.5" />
                <span>{item.label}</span>
              </button>
            );
          })}
        </div>
      </div>
    </header>
  );
}
