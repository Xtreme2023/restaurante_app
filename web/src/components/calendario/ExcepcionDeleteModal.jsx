import React from 'react';
import Modal from '../Modal';
import { Trash2 } from 'lucide-react';

/**
 * Modal para confirmar la eliminación de un día de no atención en excepcion_calendario
 * Reutiliza el componente Modal general
 */
export default function ExcepcionDeleteModal({
  isOpen,
  excepcion,
  onClose,
  onConfirm,
  isDeleting,
}) {
  if (!excepcion) return null;

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="¿Eliminar día de excepción?"
      icon={Trash2}
      maxWidth="max-w-sm"
    >
      <div className="text-center py-2">
        <div className="w-12 h-12 rounded-full bg-rose-100 text-rose-600 flex items-center justify-center mx-auto mb-3">
          <Trash2 className="w-6 h-6" />
        </div>
        <p className="text-slate-700 text-sm font-semibold">
          Fecha: {excepcion.fecha}
        </p>
        <p className="text-slate-500 text-xs mt-1">
          Motivo: <em>"{excepcion.motivo}"</em>
        </p>
        <p className="text-slate-500 text-xs mt-3">
          Al eliminar esta excepción, el restaurante volverá a estar habilitado para atención habitual y pedidos en esta fecha.
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
            onClick={() => onConfirm(excepcion)}
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
