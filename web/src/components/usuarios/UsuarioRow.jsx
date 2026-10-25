import React from 'react';
import { Eye, UserX, UserCheck, Trash2, Users } from 'lucide-react';
import UsuarioRoleBadge from './UsuarioRoleBadge';

/**
 * Fila individual de usuario dentro de la tabla
 */
export default function UsuarioRow({
  user,
  isLoadingAction,
  onSelectDetails,
  onToggleStatus,
  onDeleteClick,
  onManageFamiliares,
}) {
  const isUserActive = user.activo !== false;
  const firstName = user.nombre || user.nombres || '';
  const lastName = user.apellidos || '';
  const fullName = user.nombre_completo || `${firstName} ${lastName}`.trim() || 'Sin Nombre';
  const initials = `${firstName.charAt(0) || ''}${lastName.charAt(0) || ''}`.toUpperCase() || (user.email?.charAt(0) || 'U').toUpperCase();

  return (
    <tr className="hover:bg-slate-50/80 transition-colors duration-150 group">
      {/* Name with Avatar */}
      <td className="py-3.5 px-4 sm:px-6">
        <div className="flex items-center space-x-3">
          <div
            className={`w-9 h-9 rounded-full flex items-center justify-center font-bold text-xs shadow-xs ${
              user.rol === 'Administrador'
                ? 'bg-purple-100 text-purple-700 border border-purple-200'
                : user.rol === 'Institucion'
                ? 'bg-amber-100 text-amber-700 border border-amber-200'
                : 'bg-blue-100 text-blue-700 border border-blue-200'
            }`}
          >
            {initials}
          </div>
          <div>
            <span className="font-semibold text-slate-900 block">{fullName}</span>
          </div>
        </div>
      </td>

      {/* CI / Código */}
      <td className="py-3.5 px-4">
        <span className="inline-flex items-center font-mono text-xs bg-slate-100 px-2 py-1 rounded-md text-slate-700 font-medium">
          {user.ci_codigo || 'N/A'}
        </span>
      </td>

      {/* Teléfono (proveniente de persona vía vista_usuarios) */}
      <td className="py-3.5 px-4">
        <span className="text-slate-600 font-medium">{user.telefono || '—'}</span>
      </td>

      {/* Correo Electrónico */}
      <td className="py-3.5 px-4">
        <span className="text-slate-600 font-mono text-xs">{user.email}</span>
      </td>

      {/* Rol */}
      <td className="py-3.5 px-4">
        <UsuarioRoleBadge rol={user.rol} />
      </td>

      {/* Estado */}
      <td className="py-3.5 px-4">
        {isUserActive ? (
          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 mr-1.5 animate-pulse" /> Activo
          </span>
        ) : (
          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold bg-rose-50 text-rose-700 border border-rose-200">
            <span className="w-1.5 h-1.5 rounded-full bg-rose-500 mr-1.5" /> Inactivo
          </span>
        )}
      </td>

      {/* Acciones */}
      <td className="py-3.5 px-4 sm:px-6 text-right">
        <div className="flex items-center justify-end space-x-1.5">
          {/* Familiares (solo para empleados) */}
          {user.rol === 'Empleado' && (
            <button
              type="button"
              onClick={() => onManageFamiliares?.(user)}
              className="px-2.5 py-1.5 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 rounded-lg text-xs font-semibold transition flex items-center space-x-1"
              title="Gestionar familiares"
            >
              <Users className="w-3.5 h-3.5" />
              <span className="hidden md:inline">Familiares</span>
            </button>
          )}

          {/* Ver Detalles */}
          <button
            type="button"
            onClick={() => onSelectDetails(user)}
            className="px-2.5 py-1.5 bg-blue-50 hover:bg-blue-100 text-blue-700 rounded-lg text-xs font-semibold transition flex items-center space-x-1"
            title="Ver detalles"
          >
            <Eye className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Detalles</span>
          </button>

          {/* Anular acceso / Activar */}
          <button
            type="button"
            onClick={() => onToggleStatus(user)}
            disabled={isLoadingAction}
            className={`px-2.5 py-1.5 rounded-lg text-xs font-semibold transition flex items-center space-x-1 ${
              isUserActive
                ? 'bg-rose-50 hover:bg-rose-100 text-rose-700'
                : 'bg-emerald-50 hover:bg-emerald-100 text-emerald-700'
            }`}
            title={isUserActive ? 'Anular acceso' : 'Reactivar acceso'}
          >
            {isUserActive ? (
              <>
                <UserX className="w-3.5 h-3.5" />
                <span className="hidden md:inline">Anular acceso</span>
              </>
            ) : (
              <>
                <UserCheck className="w-3.5 h-3.5" />
                <span className="hidden md:inline">Activar</span>
              </>
            )}
          </button>

          {/* Eliminar permanente */}
          <button
            type="button"
            onClick={() => onDeleteClick(user)}
            className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
            title="Eliminar usuario"
          >
            <Trash2 className="w-3.5 h-3.5" />
          </button>
        </div>
      </td>
    </tr>
  );
}
