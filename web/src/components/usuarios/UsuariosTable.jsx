import React from 'react';
import { Users, AlertCircle, RefreshCw } from 'lucide-react';
import UsuarioRow from './UsuarioRow';

/**
 * Tabla principal con encabezado decorado, estados de carga/error/vacío y filas de usuarios
 */
export default function UsuariosTable({
  usuarios,
  totalCount,
  loading,
  error,
  onRetry,
  actionLoadingId,
  onSelectDetails,
  onToggleStatus,
  onDeleteClick,
  onManageFamiliares,
}) {
  return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-200/80 overflow-hidden">
      {/* Table Header Section */}
      <div className="bg-gradient-to-r from-blue-700 to-indigo-700 text-white px-6 py-4 flex items-center justify-between">
        <div className="flex items-center space-x-2">
          <Users className="w-5 h-5 text-blue-200" />
          <h3 className="font-bold text-lg tracking-tight">Listado de Usuarios e Integrantes</h3>
        </div>
        <span className="text-xs font-semibold bg-white/15 px-3 py-1 rounded-full border border-white/20">
          {usuarios.length} de {totalCount} registrados
        </span>
      </div>

      {/* Table Content */}
      {loading ? (
        <div className="py-16 text-center">
          <div className="w-10 h-10 border-3 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
          <p className="text-slate-500 text-sm font-medium">Cargando usuarios desde la vista de Supabase...</p>
        </div>
      ) : error ? (
        <div className="p-8 text-center bg-rose-50/50">
          <AlertCircle className="w-10 h-10 text-rose-500 mx-auto mb-2" />
          <p className="text-rose-700 font-semibold">{error}</p>
          <button
            type="button"
            onClick={onRetry}
            className="mt-3 inline-flex items-center space-x-2 px-4 py-2 bg-rose-600 text-white rounded-xl text-sm font-medium hover:bg-rose-700 transition"
          >
            <RefreshCw className="w-4 h-4" />
            <span>Reintentar</span>
          </button>
        </div>
      ) : usuarios.length === 0 ? (
        <div className="py-16 text-center px-4">
          <Users className="w-12 h-12 text-slate-300 mx-auto mb-3" />
          <h4 className="text-base font-semibold text-slate-700">No se encontraron usuarios</h4>
          <p className="text-slate-400 text-sm mt-1 max-w-sm mx-auto">
            No hay coincidencias con los criterios de búsqueda o filtros seleccionados.
          </p>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-blue-50/70 border-b border-blue-100 text-blue-900 text-xs uppercase font-bold tracking-wider">
                <th className="py-3.5 px-4 sm:px-6">Usuario / Nombre</th>
                <th className="py-3.5 px-4">CI / Código</th>
                <th className="py-3.5 px-4">Teléfono</th>
                <th className="py-3.5 px-4">Correo Electrónico</th>
                <th className="py-3.5 px-4">Rol</th>
                <th className="py-3.5 px-4">Estado</th>
                <th className="py-3.5 px-4 sm:px-6 text-right">Acciones</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-sm text-slate-700">
              {usuarios.map((u) => (
                <UsuarioRow
                  key={u.id_usuario}
                  user={u}
                  isLoadingAction={actionLoadingId === u.id_usuario}
                  onSelectDetails={onSelectDetails}
                  onToggleStatus={onToggleStatus}
                  onDeleteClick={onDeleteClick}
                  onManageFamiliares={onManageFamiliares}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
