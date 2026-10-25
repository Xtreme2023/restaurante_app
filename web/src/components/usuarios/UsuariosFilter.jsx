import React from 'react';
import { Search, X } from 'lucide-react';

/**
 * Componente para barra de búsqueda y filtros de rol y estado
 */
export default function UsuariosFilter({
  searchTerm,
  onSearchChange,
  roleFilter,
  onRoleChange,
  statusFilter,
  onStatusChange,
}) {
  const roleOptions = [
    { id: 'ALL', label: 'Todos los roles' },
    { id: 'Administrador', label: 'Administrador' },
    { id: 'Empleado', label: 'Empleado' },
    { id: 'Institucion', label: 'Institución' },
  ];

  const statusOptions = [
    { id: 'ALL', label: 'Todos' },
    { id: 'ACTIVE', label: 'Activos' },
    { id: 'INACTIVE', label: 'Inactivos' },
  ];

  return (
    <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-sm flex flex-col md:flex-row md:items-center md:justify-between gap-3">
      {/* Search Bar */}
      <div className="relative flex-1 max-w-md">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input
          type="text"
          value={searchTerm}
          onChange={(e) => onSearchChange(e.target.value)}
          placeholder="Buscar por nombre, CI, teléfono o correo..."
          className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
        />
        {searchTerm && (
          <button
            type="button"
            onClick={() => onSearchChange('')}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 text-xs"
            aria-label="Limpiar búsqueda"
          >
            <X className="w-4 h-4" />
          </button>
        )}
      </div>

      {/* Filter Pills */}
      <div className="flex flex-wrap items-center gap-2">
        {/* Role Filters */}
        <div className="flex items-center bg-slate-100 p-1 rounded-xl text-xs font-medium">
          {roleOptions.map((r) => (
            <button
              key={r.id}
              type="button"
              onClick={() => onRoleChange(r.id)}
              className={`px-3 py-1.5 rounded-lg transition ${
                roleFilter === r.id
                  ? 'bg-white text-blue-700 font-semibold shadow-xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              {r.label}
            </button>
          ))}
        </div>

        {/* Status Filters */}
        <div className="flex items-center bg-slate-100 p-1 rounded-xl text-xs font-medium">
          {statusOptions.map((s) => (
            <button
              key={s.id}
              type="button"
              onClick={() => onStatusChange(s.id)}
              className={`px-3 py-1.5 rounded-lg transition ${
                statusFilter === s.id
                  ? 'bg-white text-blue-700 font-semibold shadow-xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              {s.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
