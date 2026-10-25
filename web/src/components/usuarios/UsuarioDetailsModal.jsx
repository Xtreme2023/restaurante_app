import React from 'react';
import Modal from '../Modal';
import { User, Clock, Users } from 'lucide-react';
import UsuarioRoleBadge from './UsuarioRoleBadge';

/**
 * Modal para visualizar la información detallada de un usuario
 * Reutiliza el componente Modal general
 */
export default function UsuarioDetailsModal({ isOpen, user, onClose, onOpenFamiliares }) {
  if (!user) return null;

  const isUserActive = user.activo !== false;
  const firstName = user.nombre || user.nombres || '';
  const lastName = user.apellidos || '';
  const fullName = user.nombre_completo || `${firstName} ${lastName}`.trim() || 'Sin Nombre';
  const initials = `${firstName.charAt(0) || ''}${lastName.charAt(0) || ''}`.toUpperCase() || (user.email?.charAt(0) || 'U').toUpperCase();

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Detalles del Usuario"
      subtitle="Información institucional y datos de contacto"
      icon={User}
      maxWidth="max-w-md"
    >
      <div className="space-y-4">
        {/* User Card Header */}
        <div className="p-4 bg-slate-50 rounded-2xl border border-slate-100 flex flex-col items-center text-center">
          <div className="w-16 h-16 rounded-full bg-blue-100 text-blue-700 font-bold text-xl flex items-center justify-center mb-2 border-2 border-blue-200 shadow-xs">
            {initials}
          </div>
          <h3 className="text-lg font-bold text-slate-900">{fullName}</h3>
          <div className="mt-1.5">
            <UsuarioRoleBadge rol={user.rol} />
          </div>
        </div>

        {/* User Fields List */}
        <div className="space-y-3 text-sm">
          <div className="flex justify-between items-center py-2 border-b border-slate-100">
            <span className="text-slate-500 font-medium">Estado de cuenta</span>
            <span>
              {isUserActive ? (
                <span className="text-emerald-700 font-bold bg-emerald-50 px-2.5 py-0.5 rounded-full border border-emerald-200 text-xs">
                  Activo
                </span>
              ) : (
                <span className="text-rose-700 font-bold bg-rose-50 px-2.5 py-0.5 rounded-full border border-rose-200 text-xs">
                  Inactivo / Bloqueado
                </span>
              )}
            </span>
          </div>

          <div className="flex justify-between items-center py-2 border-b border-slate-100">
            <span className="text-slate-500 font-medium">Cédula / C.I.</span>
            <span className="font-mono font-semibold text-slate-800">{user.ci_codigo || 'N/A'}</span>
          </div>

          <div className="flex justify-between items-center py-2 border-b border-slate-100">
            <span className="text-slate-500 font-medium">Teléfono</span>
            <span className="font-semibold text-slate-800">{user.telefono || 'N/A'}</span>
          </div>

          <div className="flex justify-between items-center py-2 border-b border-slate-100">
            <span className="text-slate-500 font-medium">Correo electrónico</span>
            <span className="font-mono text-xs font-semibold text-slate-800">{user.email}</span>
          </div>

          <div className="flex justify-between items-center py-2 border-b border-slate-100">
            <span className="text-slate-500 font-medium">Fecha de registro</span>
            <span className="text-xs text-slate-600 flex items-center">
              <Clock className="w-3.5 h-3.5 mr-1 text-slate-400" />
              {user.created_at ? new Date(user.created_at).toLocaleString() : 'N/A'}
            </span>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="pt-2 space-y-2">
          {user.rol === 'Empleado' && (
            <button
              type="button"
              onClick={() => {
                onClose();
                onOpenFamiliares?.(user);
              }}
              className="w-full py-2.5 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 font-semibold rounded-xl text-sm transition flex items-center justify-center space-x-2 border border-indigo-200"
            >
              <Users className="w-4 h-4" />
              <span>Gestionar Familiares (Hijos, Cónyuge)</span>
            </button>
          )}

          <button
            type="button"
            onClick={onClose}
            className="w-full py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-800 font-semibold rounded-xl text-sm transition"
          >
            Cerrar
          </button>
        </div>
      </div>
    </Modal>
  );
}
