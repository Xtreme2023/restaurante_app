import React, { useState, useEffect } from 'react';
import Modal from '../Modal';
import { createExcepcionCalendario } from '../../lib/supabaseClient';
import { formatLocalDate } from '../../lib/dateUtils';
import { CalendarX, Calendar, AlertCircle, Check, Shield } from 'lucide-react';

/**
 * Modal para registrar días de no atención en excepcion_calendario
 * Reutiliza el componente Modal general
 */
export default function ExcepcionCreateModal({
  isOpen,
  onClose,
  initialDate,
  adminUser,
  onExcepcionCreated,
  showToast,
}) {
  const [fecha, setFecha] = useState('');
  const [motivo, setMotivo] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (initialDate) {
      setFecha(initialDate);
    } else {
      // Por defecto la fecha de hoy en formato local YYYY-MM-DD
      const today = formatLocalDate(new Date());
      setFecha(today);
    }
    setMotivo('');
    setError(null);
  }, [initialDate, isOpen]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);

    if (!fecha) {
      setError('Debes seleccionar una fecha.');
      return;
    }
    if (!motivo.trim()) {
      setError('Debes ingresar el motivo de no atención.');
      return;
    }

    try {
      setSubmitting(true);
      const adminId = adminUser?.id || adminUser?.id_usuario;
      await createExcepcionCalendario({
        fecha,
        motivo: motivo.trim(),
        id_encargado: adminId,
      });

      showToast?.(`Día de excepción registrado para el ${fecha}.`);
      onClose();
      await onExcepcionCreated?.();
    } catch (err) {
      console.error('Error al registrar excepcion_calendario:', err);
      setError(err.message || 'Error al guardar el día de excepción.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Registrar Día de No Atención"
      subtitle="Define un día de excepción en el calendario donde el restaurante no prestará servicio"
      icon={CalendarX}
      maxWidth="max-w-md"
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        {error && (
          <div className="p-3 bg-rose-50 border border-rose-200 rounded-xl text-rose-700 text-xs flex items-start space-x-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5 text-rose-500" />
            <div>
              <span className="font-bold block">No se pudo registrar:</span>
              <span>{error}</span>
            </div>
          </div>
        )}

        {/* Encargado Admin info banner */}
        <div className="bg-purple-50/80 border border-purple-200/80 rounded-xl p-3 flex items-center space-x-2.5 text-xs text-purple-900">
          <Shield className="w-4 h-4 text-purple-600 flex-shrink-0" />
          <div>
            <span className="font-semibold">Encargado responsable: </span>
            <span className="font-medium text-purple-700">{adminUser?.email || 'Administrador'}</span>
          </div>
        </div>

        {/* Fecha */}
        <div>
          <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
            Fecha de No Atención *
          </label>
          <div className="relative">
            <Calendar className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="date"
              value={fecha}
              onChange={(e) => setFecha(e.target.value)}
              required
              className="w-full pl-10 pr-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:bg-white font-medium"
            />
          </div>
          <p className="text-[11px] text-slate-500 mt-1">
            En esta fecha, los empleados verán en su portal que no hay servicio ni reservas de almuerzo.
          </p>
        </div>

        {/* Motivo */}
        <div>
          <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
            Motivo de la Excepción *
          </label>
          <input
            type="text"
            value={motivo}
            onChange={(e) => setMotivo(e.target.value)}
            placeholder="Ej. Feriado Nacional, Mantenimiento preventivo, Feriado institucional"
            required
            className="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:bg-white"
          />
        </div>

        {/* Action Buttons */}
        <div className="pt-3 flex items-center justify-end space-x-3 border-t border-slate-100">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 text-sm font-medium text-slate-600 hover:text-slate-800 hover:bg-slate-100 rounded-xl transition"
          >
            Cancelar
          </button>
          <button
            type="submit"
            disabled={submitting}
            className="flex items-center space-x-2 px-5 py-2.5 bg-rose-600 hover:bg-rose-700 text-white text-sm font-semibold rounded-xl shadow-md hover:shadow-rose-600/30 transition-all disabled:opacity-50"
          >
            {submitting ? (
              <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
            ) : (
              <>
                <Check className="w-4 h-4" />
                <span>Guardar Excepción</span>
              </>
            )}
          </button>
        </div>
      </form>
    </Modal>
  );
}
