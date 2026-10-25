import React from 'react';
import { Shield, Briefcase, Building2 } from 'lucide-react';

/**
 * Componente para renderizar la insignia de rol de usuario
 */
export default function UsuarioRoleBadge({ rol }) {
  switch (rol) {
    case 'Administrador':
      return (
        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-purple-100 text-purple-800 border border-purple-200">
          <Shield className="w-3 h-3 mr-1 text-purple-600" /> Administrador
        </span>
      );
    case 'Empleado':
      return (
        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 border border-emerald-200">
          <Briefcase className="w-3 h-3 mr-1 text-emerald-600" /> Empleado
        </span>
      );
    case 'Institucion':
      return (
        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-amber-100 text-amber-800 border border-amber-200">
          <Building2 className="w-3 h-3 mr-1 text-amber-600" /> Institución
        </span>
      );
    default:
      return (
        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-slate-100 text-slate-800">
          {rol || 'Sin Rol'}
        </span>
      );
  }
}
