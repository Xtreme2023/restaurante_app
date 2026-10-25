import React from 'react';
import { Users, Shield, Briefcase, Building2, CheckCircle2 } from 'lucide-react';

/**
 * Componente que muestra las tarjetas de estadísticas rápidas de usuarios
 */
export default function UsuariosStats({ stats }) {
  const {
    total = 0,
    adminCount = 0,
    empleadoCount = 0,
    institucionCount = 0,
    activos = 0,
  } = stats || {};

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3 sm:gap-4">
      {/* Total Usuarios */}
      <div className="bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs flex items-center space-x-3">
        <div className="p-2.5 bg-blue-50 text-blue-600 rounded-lg">
          <Users className="w-5 h-5" />
        </div>
        <div>
          <p className="text-xs font-medium text-slate-500">Total Usuarios</p>
          <p className="text-xl font-bold text-slate-900">{total}</p>
        </div>
      </div>

      {/* Administradores */}
      <div className="bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs flex items-center space-x-3">
        <div className="p-2.5 bg-purple-50 text-purple-600 rounded-lg">
          <Shield className="w-5 h-5" />
        </div>
        <div>
          <p className="text-xs font-medium text-slate-500">Administradores</p>
          <p className="text-xl font-bold text-purple-700">{adminCount}</p>
        </div>
      </div>

      {/* Empleados */}
      <div className="bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs flex items-center space-x-3">
        <div className="p-2.5 bg-emerald-50 text-emerald-600 rounded-lg">
          <Briefcase className="w-5 h-5" />
        </div>
        <div>
          <p className="text-xs font-medium text-slate-500">Empleados</p>
          <p className="text-xl font-bold text-emerald-700">{empleadoCount}</p>
        </div>
      </div>

      {/* Instituciones */}
      <div className="bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs flex items-center space-x-3">
        <div className="p-2.5 bg-amber-50 text-amber-600 rounded-lg">
          <Building2 className="w-5 h-5" />
        </div>
        <div>
          <p className="text-xs font-medium text-slate-500">Instituciones</p>
          <p className="text-xl font-bold text-amber-700">{institucionCount}</p>
        </div>
      </div>

      {/* Cuentas Activas */}
      <div className="bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs flex items-center space-x-3 col-span-2 sm:col-span-1">
        <div className="p-2.5 bg-teal-50 text-teal-600 rounded-lg">
          <CheckCircle2 className="w-5 h-5" />
        </div>
        <div>
          <p className="text-xs font-medium text-slate-500">Cuentas Activas</p>
          <p className="text-xl font-bold text-teal-700">{activos}</p>
        </div>
      </div>
    </div>
  );
}
