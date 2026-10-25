import React from 'react';
import Modal from '../Modal';
import { Trash2 } from 'lucide-react';

/**
 * Modal para confirmar la eliminación permanente de un usuario
 * Reutiliza el componente Modal general
 */
export default function UsuarioDeleteModal({
  isOpen,
  user,
  onClose,
  onConfirm,
  isDeleting,
}) {
  if (!user) return null;

  const firstName = user.nombre || user.nombres || '';
  const lastName = user.apellidos || '';
  const fullName = user.nombre_completo || `${firstName} ${lastName}`.trim() || 'este usuario';

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="¿Eliminar usuario?"
      icon={Trash2}
      maxWidth="max-w-sm"
    >
      <div className="text-center py-2">
        <div className="w-12 h-12 rounded-full bg-rose-100 text-rose-600 flex items-center justify-center mx-auto mb-3">
          <Trash2 className="w-6 h-6" />
        </div>
        <p className="text-slate-600 text-sm">
          Esta acción borrará permanentemente a <strong>{fullName}</strong> de la base de datos y de la autenticación de Supabase.
        </p>
        <p className="text-slate-400 text-xs mt-2">
          Esta acción no se puede deshacer.
        </p>

        <div className="mt-6 flex items-center justify-center space-x-3">
          <button
            type="button"
            onClick={onClose}
            disabled={isDeleting}
            className="px-4 py-2 bg-slate-100 text-slate-700 text-sm font-medium rounded-xl hover:bg-slate-200 transition"
          >
            Cancelar
          </button>
          <button
            type="button"
            onClick={() => onConfirm(user.id_usuario)}
            disabled={isDeleting}
            className="flex items-center space-x-2 px-4 py-2 bg-rose-600 hover:bg-rose-700 text-white text-sm font-semibold rounded-xl transition disabled:opacity-50"
          >
            {isDeleting ? (
              <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
            ) : (
              <span>Sí, Eliminar</span>
            )}
          </button>
        </div>
      </div>
    </Modal>
  );
}
