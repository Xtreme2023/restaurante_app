import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { useAuth } from '../../context/AuthContext';
import { 
  fetchExcepcionesCalendario, 
  deleteExcepcionCalendario 
} from '../../lib/supabaseClient';
import { formatLocalDate } from '../../lib/dateUtils';
import { 
  CalendarDays, 
  CalendarPlus, 
  RefreshCw, 
  CalendarX, 
  CheckCircle2, 
  Clock, 
  ShieldAlert, 
  Sparkles, 
  Trash2 
} from 'lucide-react';

import CalendarioGrid from './CalendarioGrid';
import ExcepcionCreateModal from './ExcepcionCreateModal';
import ExcepcionDeleteModal from './ExcepcionDeleteModal';

export default function CalendarioSection() {
  const { user, profile, isAdmin, role } = useAuth();

  const [excepciones, setExcepciones] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Fecha para navegar el mes actual en el calendario
  const [currentMonth, setCurrentMonth] = useState(new Date());

  // Modales
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [selectedDateForCreate, setSelectedDateForCreate] = useState('');
  const [excepcionToDelete, setExcepcionToDelete] = useState(null);
  const [isDeleting, setIsDeleting] = useState(false);

  // Toast
  const [toastMessage, setToastMessage] = useState(null);

  const showToast = (msg) => {
    setToastMessage(msg);
    setTimeout(() => {
      setToastMessage(null);
    }, 4000);
  };

  /**
   * Cargar excepciones desde excepcion_calendario en Supabase
   */
  const loadExcepciones = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await fetchExcepcionesCalendario();
      setExcepciones(data || []);
    } catch (err) {
      console.error('Error al cargar excepcion_calendario:', err);
      setError('No se pudieron cargar los días de excepción. Verifica tu conexión con la base de datos.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadExcepciones();
  }, [loadExcepciones]);

  // Navegación de mes
  const handlePrevMonth = () => {
    setCurrentMonth((prev) => new Date(prev.getFullYear(), prev.getMonth() - 1, 1));
  };

  const handleNextMonth = () => {
    setCurrentMonth((prev) => new Date(prev.getFullYear(), prev.getMonth() + 1, 1));
  };

  const handleToday = () => {
    setCurrentMonth(new Date());
  };

  // Clic en un día del calendario
  const handleSelectDate = (dateStr, excepcion) => {
    if (excepcion) {
      // Si ya tiene excepción y es admin, permitir confirmar eliminación
      if (isAdmin) {
        setExcepcionToDelete(excepcion);
      }
    } else if (isAdmin) {
      // Si no tiene excepción y es admin, abrir modal con fecha preseleccionada
      setSelectedDateForCreate(dateStr);
      setShowCreateModal(true);
    }
  };

  // Confirmar eliminación de excepción
  const handleConfirmDelete = async (excepcion) => {
    try {
      setIsDeleting(true);
      await deleteExcepcionCalendario(excepcion);
      showToast('Día de excepción eliminado. Se restablece la atención.');
      setExcepcionToDelete(null);
      await loadExcepciones();
    } catch (err) {
      console.error('Error eliminando excepción:', err);
      alert('Error al eliminar la excepción.');
    } finally {
      setIsDeleting(false);
    }
  };

  // Cálculos estadísticos
  const todayStr = useMemo(() => formatLocalDate(new Date()), []);

  const stats = useMemo(() => {
    const curYear = currentMonth.getFullYear();
    const curMonth = currentMonth.getMonth();

    // Excepciones del mes en vista
    const thisMonthExceptions = excepciones.filter((e) => {
      if (!e.fecha) return false;
      const d = new Date(e.fecha);
      return d.getFullYear() === curYear && d.getMonth() === curMonth;
    });

    // Próxima excepción a partir de hoy
    const futureExceptions = excepciones
      .filter((e) => e.fecha >= todayStr)
      .sort((a, b) => a.fecha.localeCompare(b.fecha));

    const nextException = futureExceptions[0] || null;

    // Verificar si hoy es excepción
    const isTodayException = excepciones.some((e) => e.fecha?.split('T')[0] === todayStr);

    return {
      monthCount: thisMonthExceptions.length,
      nextException,
      totalYear: excepciones.filter((e) => new Date(e.fecha).getFullYear() === curYear).length,
      isTodayException,
    };
  }, [excepciones, currentMonth, todayStr]);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      {/* Toast Notificación */}
      {toastMessage && (
        <div className="fixed bottom-5 right-5 z-50 bg-emerald-600 text-white px-5 py-3.5 rounded-xl shadow-2xl flex items-center space-x-3 animate-fade-in border border-emerald-400">
          <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
          <span className="text-sm font-medium">{toastMessage}</span>
        </div>
      )}

      {/* Header Banner */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 bg-white p-6 rounded-2xl shadow-sm border border-slate-200/80">
        <div>
          <div className="flex items-center space-x-2">
            <div className="p-2 bg-rose-50 rounded-xl text-rose-600">
              <CalendarDays className="w-6 h-6" />
            </div>
            <h1 className="text-2xl font-bold text-slate-900 tracking-tight">
              Calendario de Días de No Atención
            </h1>
          </div>
          <p className="text-slate-500 text-sm mt-1">
            Gestión institucional de excepciones de calendario y días en que el comedor no prestará servicio a empleados.
          </p>
        </div>

        <div className="flex items-center space-x-3">
          <button
            type="button"
            onClick={loadExcepciones}
            disabled={loading}
            className="p-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-600 transition shadow-xs"
            title="Refrescar datos"
          >
            <RefreshCw className={`w-5 h-5 ${loading ? 'animate-spin text-blue-600' : ''}`} />
          </button>

          {/* Solo el Administrador puede ingresar días de excepción */}
          {isAdmin && (
            <button
              type="button"
              onClick={() => {
                setSelectedDateForCreate('');
                setShowCreateModal(true);
              }}
              className="flex items-center space-x-2 bg-rose-600 hover:bg-rose-700 text-white font-semibold px-4 py-2.5 rounded-xl shadow-md hover:shadow-rose-600/20 transform active:scale-95 transition-all duration-200"
            >
              <CalendarPlus className="w-5 h-5" />
              <span>Registrar Día de Excepción</span>
            </button>
          )}
        </div>
      </div>

      {/* Tarjetas de Métricas Rápidas */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Estado Hoy */}
        <div className="bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs flex items-center space-x-3">
          <div className={`p-2.5 rounded-lg ${stats.isTodayException ? 'bg-rose-100 text-rose-700' : 'bg-emerald-100 text-emerald-700'}`}>
            {stats.isTodayException ? <CalendarX className="w-5 h-5" /> : <CheckCircle2 className="w-5 h-5" />}
          </div>
          <div>
            <p className="text-xs font-medium text-slate-500">Estado de Atención Hoy</p>
            <p className={`text-sm font-bold ${stats.isTodayException ? 'text-rose-700' : 'text-emerald-700'}`}>
              {stats.isTodayException ? 'No hay atención (Cerrado)' : 'Atención Normal'}
            </p>
          </div>
        </div>

        {/* Excepciones este mes */}
        <div className="bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs flex items-center space-x-3">
          <div className="p-2.5 bg-amber-50 text-amber-600 rounded-lg">
            <Clock className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs font-medium text-slate-500">Días sin atención este mes</p>
            <p className="text-xl font-bold text-slate-900">{stats.monthCount} días</p>
          </div>
        </div>

        {/* Próximo día de excepción */}
        <div className="bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs flex items-center space-x-3 sm:col-span-2 lg:col-span-2">
          <div className="p-2.5 bg-purple-50 text-purple-600 rounded-lg flex-shrink-0">
            <ShieldAlert className="w-5 h-5" />
          </div>
          <div className="truncate">
            <p className="text-xs font-medium text-slate-500">Próximo día de no atención</p>
            {stats.nextException ? (
              <p className="text-sm font-bold text-purple-900 truncate">
                {stats.nextException.fecha}: <span className="font-normal text-purple-700">"{stats.nextException.motivo}"</span>
              </p>
            ) : (
              <p className="text-sm font-semibold text-slate-400">No hay excepciones próximas</p>
            )}
          </div>
        </div>
      </div>

      {/* Cuadrícula interactiva del Calendario */}
      <CalendarioGrid
        currentMonth={currentMonth}
        onPrevMonth={handlePrevMonth}
        onNextMonth={handleNextMonth}
        onToday={handleToday}
        excepciones={excepciones}
        isAdmin={isAdmin}
        onSelectDate={handleSelectDate}
        onDeleteExcepcion={(exc) => setExcepcionToDelete(exc)}
      />

      {/* Listado y Agenda de Próximas Excepciones Registradas */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200/80 p-6 space-y-4">
        <div className="flex items-center justify-between border-b border-slate-100 pb-3">
          <div className="flex items-center space-x-2">
            <CalendarX className="w-5 h-5 text-rose-600" />
            <h3 className="font-bold text-base text-slate-900">Listado de Días de No Atención</h3>
          </div>
          <span className="text-xs font-semibold bg-rose-50 text-rose-700 px-3 py-1 rounded-full border border-rose-200">
            {excepciones.length} excepciones en total
          </span>
        </div>

        {loading ? (
          <div className="py-8 text-center text-slate-500 text-sm">
            <div className="w-8 h-8 border-3 border-rose-600 border-t-transparent rounded-full animate-spin mx-auto mb-2" />
            Cargando excepciones de calendario...
          </div>
        ) : error ? (
          <div className="p-4 bg-rose-50 rounded-xl text-rose-700 text-xs">
            {error}
          </div>
        ) : excepciones.length === 0 ? (
          <div className="py-8 text-center text-slate-400 text-sm">
            No se han registrado días de no atención. Todos los días cuentan con servicio habitual.
          </div>
        ) : (
          <div className="divide-y divide-slate-100">
            {excepciones.map((item) => (
              <div
                key={item.id_excepcion || item.fecha}
                className="py-3 flex items-center justify-between hover:bg-slate-50/60 px-2 rounded-xl transition"
              >
                <div className="flex items-center space-x-3">
                  <div className="w-10 h-10 rounded-xl bg-rose-100 text-rose-700 font-bold flex flex-col items-center justify-center text-xs border border-rose-200">
                    <span>{item.fecha?.split('-')[2] || '—'}</span>
                    <span className="text-[9px] uppercase font-semibold">
                      {new Date(item.fecha + 'T00:00:00').toLocaleString('es-ES', { month: 'short' })}
                    </span>
                  </div>
                  <div>
                    <p className="text-sm font-bold text-slate-800">{item.motivo}</p>
                    <p className="text-xs text-slate-400">
                      Fecha: {item.fecha} {item.id_encargado ? `• Registrado por Admin` : ''}
                    </p>
                  </div>
                </div>

                {isAdmin && (
                  <button
                    type="button"
                    onClick={() => setExcepcionToDelete(item)}
                    className="p-2 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
                    title="Eliminar excepción"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Modal: Registrar Día de Excepción (reutiliza Modal.js) */}
      <ExcepcionCreateModal
        isOpen={showCreateModal}
        onClose={() => setShowCreateModal(false)}
        initialDate={selectedDateForCreate}
        adminUser={user}
        onExcepcionCreated={loadExcepciones}
        showToast={showToast}
      />

      {/* Modal: Confirmar Eliminación (reutiliza Modal.js) */}
      <ExcepcionDeleteModal
        isOpen={!!excepcionToDelete}
        excepcion={excepcionToDelete}
        onClose={() => setExcepcionToDelete(null)}
        onConfirm={handleConfirmDelete}
        isDeleting={isDeleting}
      />
    </div>
  );
}
