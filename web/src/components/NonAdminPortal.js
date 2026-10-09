import React from 'react';
import { useAuth } from '../context/AuthContext';
import { 
  ShieldAlert, 
  Utensils, 
  Calendar, 
  Clock, 
  UserCheck, 
  Sparkles, 
  CheckCircle,
  Building,
  ChefHat
} from 'lucide-react';

export default function NonAdminPortal({ setActiveTab }) {
  const { profile, user, role } = useAuth();

  const displayName = profile?.nombres
    ? `${profile.nombres} ${profile.apellidos || ''}`
    : user?.email?.split('@')[0] || 'Usuario';

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      {/* Role Notice Banner */}
      <div className="bg-gradient-to-r from-amber-50 to-orange-50 border border-amber-200/80 rounded-2xl p-5 flex items-start space-x-4 shadow-sm">
        <div className="p-2.5 bg-amber-500/10 text-amber-700 rounded-xl flex-shrink-0">
          <ShieldAlert className="w-6 h-6" />
        </div>
        <div className="flex-1">
          <h3 className="text-base font-bold text-amber-900">
            Vista de {role === 'Institucion' ? 'Institución' : 'Empleado'}
          </h3>
          <p className="text-sm text-amber-800/90 mt-1">
            Has iniciado sesión con el rol de <strong>{role}</strong>. El módulo de <em>Administración y Gestión de Usuarios</em> está reservado exclusivamente para cuentas con rol de <strong>Administrador</strong>.
          </p>
        </div>
      </div>

      {/* Welcome Banner */}
      <div className="bg-gradient-to-r from-blue-700 via-blue-600 to-indigo-700 rounded-2xl p-6 sm:p-8 text-white shadow-lg relative overflow-hidden">
        <div className="relative z-10">
          <div className="inline-flex items-center space-x-1.5 bg-white/20 text-white text-xs font-semibold px-3 py-1 rounded-full mb-3 backdrop-blur-xs">
            <Sparkles className="w-3.5 h-3.5 text-yellow-300" />
            <span>Portal del Comedor Institucional</span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight">
            ¡Bienvenido(a), {displayName}!
          </h1>
          <p className="text-blue-100 text-sm mt-2 max-w-xl">
            Aquí puedes consultar el menú semanal planificado para los almuerzos, revisar tus datos personales y gestionar tu cuenta.
          </p>

          <div className="mt-5 flex flex-wrap gap-3">
            <button
              onClick={() => setActiveTab('menu')}
              className="px-4 py-2.5 bg-white text-blue-700 hover:bg-blue-50 font-semibold rounded-xl text-sm shadow-md transition flex items-center space-x-2"
            >
              <Utensils className="w-4 h-4" />
              <span>Ver Menú Semanal</span>
            </button>
            <button
              onClick={() => setActiveTab('cuenta')}
              className="px-4 py-2.5 bg-blue-800/60 hover:bg-blue-800/80 text-white font-medium rounded-xl text-sm border border-white/20 transition flex items-center space-x-2"
            >
              <UserCheck className="w-4 h-4" />
              <span>Gestionar Mi Cuenta</span>
            </button>
          </div>
        </div>
      </div>

      {/* Today's Special & Details Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Today's Lunch Card */}
        <div className="md:col-span-2 bg-white rounded-2xl shadow-sm border border-slate-200/80 p-6 space-y-4">
          <div className="flex items-center justify-between border-b border-slate-100 pb-4">
            <div className="flex items-center space-x-3">
              <div className="p-2.5 bg-emerald-50 text-emerald-600 rounded-xl">
                <ChefHat className="w-6 h-6" />
              </div>
              <div>
                <h3 className="font-bold text-slate-900 text-lg">Almuerzo de Hoy</h3>
                <p className="text-xs text-slate-500">Menú del día programado</p>
              </div>
            </div>
            <span className="text-xs font-semibold bg-emerald-100 text-emerald-800 px-3 py-1 rounded-full">
              Disponible 12:00 - 15:00
            </span>
          </div>

          <div className="p-4 bg-slate-50 rounded-xl border border-slate-100 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
            <div>
              <p className="font-bold text-slate-800 text-base">Pollo a la plancha con ensalada fresca y guarnición</p>
              <p className="text-xs text-slate-500 mt-1">Incluye sopa del día, postre de frutas y refresco natural.</p>
            </div>
            <span className="inline-flex items-center text-xs font-semibold text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-lg border border-emerald-200">
              <CheckCircle className="w-3.5 h-3.5 mr-1" /> Servido
            </span>
          </div>

          <div className="text-right">
            <button
              onClick={() => setActiveTab('menu')}
              className="text-xs font-semibold text-blue-600 hover:text-blue-700 hover:underline"
            >
              Ver programación de toda la semana →
            </button>
          </div>
        </div>

        {/* User Card */}
        <div className="bg-white rounded-2xl shadow-sm border border-slate-200/80 p-6 space-y-4">
          <h3 className="font-bold text-slate-900 text-base flex items-center space-x-2">
            <UserCheck className="w-5 h-5 text-blue-600" />
            <span>Ficha del Usuario</span>
          </h3>

          <div className="space-y-2.5 text-xs text-slate-600">
            <div className="flex justify-between py-1.5 border-b border-slate-100">
              <span className="font-medium text-slate-400">Rol:</span>
              <span className="font-bold text-slate-800">{role}</span>
            </div>
            <div className="flex justify-between py-1.5 border-b border-slate-100">
              <span className="font-medium text-slate-400">C.I.:</span>
              <span className="font-mono font-semibold text-slate-800">{profile?.ci_codigo || 'N/A'}</span>
            </div>
            <div className="flex justify-between py-1.5 border-b border-slate-100">
              <span className="font-medium text-slate-400">Teléfono:</span>
              <span className="font-semibold text-slate-800">{profile?.telefono || 'N/A'}</span>
            </div>
            <div className="flex justify-between py-1.5 border-b border-slate-100">
              <span className="font-medium text-slate-400">Correo:</span>
              <span className="font-mono text-slate-800 truncate max-w-[140px]">{user?.email}</span>
            </div>
          </div>

          <button
            onClick={() => setActiveTab('cuenta')}
            className="w-full py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-semibold rounded-xl text-xs transition"
          >
            Editar mis datos
          </button>
        </div>
      </div>
    </div>
  );
}
