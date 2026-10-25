import React, { useState, useEffect, useMemo, useCallback } from 'react';
import Modal from '../Modal';
import { menuDiaService } from '../../lib/menu';
import { 
  CalendarDays, 
  Calendar, 
  Check, 
  AlertCircle, 
  Search, 
  Trash2, 
  RotateCcw, 
  Save, 
  Clock, 
  ChefHat,
  Sparkles
} from 'lucide-react';

import { 
  getMondayOfWeek, 
  generateWeekDays, 
  formatLocalDate, 
  parseLocalDate 
} from '../../lib/dateUtils';

const DRAFT_STORAGE_KEY = 'restaurante_menu_semanal_draft';

export default function MenuSemanalModal({
  isOpen,
  onClose,
  platos = [],
  menus = [],
  initialMonday,
  initialDayIndex = 0,
  onMenuCreated,
  showToast,
}) {
  // Fecha base para la semana (Lunes)
  const [startMonday, setStartMonday] = useState(() => initialMonday || getMondayOfWeek());
  
  // Días de la semana calculados (Lunes a Viernes)
  const weekDays = useMemo(() => generateWeekDays(startMonday), [startMonday]);

  // Día activo seleccionado en el modal para asignar platos (0: Lunes, 1: Martes...)
  const [activeDayIndex, setActiveDayIndex] = useState(initialDayIndex || 0);

  // Mapeo de platos seleccionados por fecha: { 'YYYY-MM-DD': [platoId1, platoId2] }
  const [selectedPlatosByDate, setSelectedPlatosByDate] = useState({});

  // Publicación global para toda la semana
  const [publicarSemana, setPublicarSemana] = useState(true);

  // Estados de carga y error
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState(null);
  const [searchPlato, setSearchPlato] = useState('');

  // Estado del guardado temporal / borrador
  const [draftSavedAt, setDraftSavedAt] = useState(null);
  const [isInitialized, setIsInitialized] = useState(false);

  // Estado original de la BD para detección de cambios (dirty checking)
  const [originalWeekData, setOriginalWeekData] = useState({ platosByDate: {}, isPublished: true });

  // ========================================================
  // EXTRAER DATOS EXISTENTES DESDE SUPABASE (menus)
  // ========================================================
  const getExistingWeekData = useCallback((mondayStr) => {
    const days = generateWeekDays(mondayStr);
    const data = {};
    let anyPublished = false;
    let hasAnyMenu = false;

    days.forEach((d) => {
      const m = menus.find((item) => item.fecha && item.fecha.split('T')[0] === d.dateStr);
      if (m) {
        hasAnyMenu = true;
        if (m.estado_publicacion === true || m.estado_publicacion === 'Publicado') {
          anyPublished = true;
        }
        data[d.dateStr] = Array.from(new Set((m.platos || []).map((p) => p.id_plato)));
      } else {
        data[d.dateStr] = [];
      }
    });

    return {
      platosByDate: data,
      isPublished: hasAnyMenu ? anyPublished : true,
      hasAnyMenu,
    };
  }, [menus]);

  // ========================================================
  // INICIALIZACIÓN AL ABRIR EL MODAL
  // ========================================================
  useEffect(() => {
    if (!isOpen) {
      setIsInitialized(false);
      return;
    }

    const targetMonday = initialMonday || getMondayOfWeek();
    setStartMonday(targetMonday);
    setActiveDayIndex(initialDayIndex || 0);
    setSearchPlato('');
    setFormError(null);

    // 1. Obtener los platos guardados en el sistema para esta semana
    const existing = getExistingWeekData(targetMonday);
    setOriginalWeekData(existing);

    // 2. Verificar si existe un borrador temporal no guardado en localStorage para ESTA misma semana
    let loadedFromDraft = false;
    try {
      const rawDraft = localStorage.getItem(`${DRAFT_STORAGE_KEY}_${targetMonday}`);
      if (rawDraft) {
        const draft = JSON.parse(rawDraft);
        if (draft.selectedPlatosByDate && Object.keys(draft.selectedPlatosByDate).length > 0) {
          setSelectedPlatosByDate(draft.selectedPlatosByDate);
          if (typeof draft.publicarSemana === 'boolean') setPublicarSemana(draft.publicarSemana);
          if (draft.savedAt) setDraftSavedAt(new Date(draft.savedAt).toLocaleTimeString());
          loadedFromDraft = true;
        }
      }
    } catch (err) {
      console.warn('Error leyendo borrador local:', err);
    }

    // Si no hay borrador local para esta semana, cargar los datos existentes de la base de datos
    if (!loadedFromDraft) {
      setSelectedPlatosByDate(existing.platosByDate);
      setPublicarSemana(existing.isPublished);
      setDraftSavedAt(null);
    }

    setIsInitialized(true);
  }, [isOpen, initialMonday, initialDayIndex, getExistingWeekData]);

  // ========================================================
  // GUARDADO TEMPORAL LOCAL (localStorage por semana)
  // ========================================================
  const saveDraftLocally = useCallback(() => {
    if (!isOpen || !startMonday || !isInitialized) return;
    try {
      const now = new Date();
      const draftData = {
        startMonday,
        selectedPlatosByDate,
        publicarSemana,
        savedAt: now.toISOString(),
      };
      localStorage.setItem(`${DRAFT_STORAGE_KEY}_${startMonday}`, JSON.stringify(draftData));
      setDraftSavedAt(now.toLocaleTimeString());
    } catch (err) {
      console.warn('No se pudo guardar borrador local:', err);
    }
  }, [startMonday, selectedPlatosByDate, publicarSemana, isOpen, isInitialized]);

  useEffect(() => {
    if (isOpen && isInitialized && Object.keys(selectedPlatosByDate).length > 0) {
      saveDraftLocally();
    }
  }, [selectedPlatosByDate, startMonday, publicarSemana, isOpen, isInitialized, saveDraftLocally]);

  // Limpiar borrador temporal manualmente y restaurar los platos guardados en el sistema
  const handleClearDraft = () => {
    if (window.confirm('¿Deseas descartar los cambios temporales y restaurar los platos guardados en el sistema?')) {
      try {
        localStorage.removeItem(`${DRAFT_STORAGE_KEY}_${startMonday}`);
        localStorage.removeItem(DRAFT_STORAGE_KEY);
      } catch (err) {}
      setDraftSavedAt(null);
      const existing = getExistingWeekData(startMonday);
      setOriginalWeekData(existing);
      setSelectedPlatosByDate(existing.platosByDate);
      setPublicarSemana(existing.isPublished);
      showToast?.('Borrador descartado. Se restauraron los datos del menú guardado.');
    }
  };

  // Alternar selección de un plato para el día activo
  const togglePlatoForActiveDay = (platoId) => {
    const activeDateStr = weekDays[activeDayIndex]?.dateStr;
    if (!activeDateStr) return;

    setSelectedPlatosByDate((prev) => {
      const currentList = Array.from(new Set(prev[activeDateStr] || []));
      const exists = currentList.some((id) => String(id) === String(platoId));
      const updated = exists
        ? currentList.filter((id) => String(id) !== String(platoId))
        : [...currentList, platoId];

      return {
        ...prev,
        [activeDateStr]: updated,
      };
    });
  };

  // Cambiar semana base (Lunes) desde el selector de fecha del modal
  const handleMondayChange = (e) => {
    if (!e.target.value) return;
    const newMonday = getMondayOfWeek(e.target.value);
    setStartMonday(newMonday);
    setActiveDayIndex(0);

    const existing = getExistingWeekData(newMonday);
    setOriginalWeekData(existing);

    // Revisar si hay borrador para la nueva semana seleccionada
    let loadedFromDraft = false;
    try {
      const rawDraft = localStorage.getItem(`${DRAFT_STORAGE_KEY}_${newMonday}`);
      if (rawDraft) {
        const draft = JSON.parse(rawDraft);
        if (draft.selectedPlatosByDate && Object.keys(draft.selectedPlatosByDate).length > 0) {
          setSelectedPlatosByDate(draft.selectedPlatosByDate);
          if (typeof draft.publicarSemana === 'boolean') setPublicarSemana(draft.publicarSemana);
          if (draft.savedAt) setDraftSavedAt(new Date(draft.savedAt).toLocaleTimeString());
          loadedFromDraft = true;
        }
      }
    } catch (err) {}

    if (!loadedFromDraft) {
      setSelectedPlatosByDate(existing.platosByDate);
      setPublicarSemana(existing.isPublished);
      setDraftSavedAt(null);
    }
  };

  // Platos filtrados por buscador dentro del modal
  const filteredPlatos = useMemo(() => {
    if (!searchPlato.trim()) return platos;
    const q = searchPlato.toLowerCase();
    return platos.filter(
      (p) => p.nombre?.toLowerCase().includes(q) || p.descripcion?.toLowerCase().includes(q)
    );
  }, [platos, searchPlato]);

  // Validación y envío atómico en lote a Supabase
  const handleSaveWeekMenu = async (e) => {
    e.preventDefault();
    setFormError(null);

    // Validar que al menos un día tenga platos asignados
    const totalSelected = Object.values(selectedPlatosByDate).reduce(
      (acc, arr) => acc + (arr?.length || 0),
      0
    );

    if (totalSelected === 0) {
      setFormError('Debes asignar al menos un plato a los días de la semana.');
      return;
    }

    // Detección de cambios (Dirty Checking): filtrar solo los días que sufrieron modificaciones
    const diasModificados = weekDays.filter((d) => {
      const prevPlatos = (originalWeekData?.platosByDate?.[d.dateStr] || [])
        .map(Number)
        .sort((a, b) => a - b);
      const currentPlatos = Array.from(new Set((selectedPlatosByDate[d.dateStr] || []).map(Number)))
        .sort((a, b) => a - b);

      // 1. ¿Cambiaron los platos de este día?
      const platosChanged =
        prevPlatos.length !== currentPlatos.length ||
        prevPlatos.some((id, idx) => id !== currentPlatos[idx]);

      if (platosChanged) return true;

      // 2. ¿Cambió el estado de publicación global y este día tiene menú o platos asignados?
      const estadoChanged =
        typeof originalWeekData?.isPublished === 'boolean' &&
        publicarSemana !== originalWeekData.isPublished;
      const hasContent = currentPlatos.length > 0 || prevPlatos.length > 0;
      if (estadoChanged && hasContent) return true;

      return false;
    });

    if (diasModificados.length === 0) {
      showToast?.('No se detectaron modificaciones en el menú de la semana.');
      onClose();
      return;
    }

    // Construir el payload exclusivamente con los días modificados (evitando tocar otros días u otras semanas)
    const diasPayload = diasModificados.map((d) => ({
      fecha: d.dateStr,
      estado_publicacion: publicarSemana,
      platos_ids: Array.from(new Set((selectedPlatosByDate[d.dateStr] || []).map(Number))),
    }));

    try {
      setSubmitting(true);
      await menuDiaService.guardarMenuSemanal(diasPayload);

      // Limpiar el borrador temporal guardado en localStorage
      try {
        localStorage.removeItem(`${DRAFT_STORAGE_KEY}_${startMonday}`);
        localStorage.removeItem(DRAFT_STORAGE_KEY);
      } catch (err) {}
      setDraftSavedAt(null);

      const nombresDias = diasModificados.map((d) => d.dayName).join(', ');
      showToast?.(
        `Menú actualizado exitosamente para: ${nombresDias}.`
      );

      onClose();
      await onMenuCreated?.();
    } catch (err) {
      console.error('Error al guardar menú semanal:', err);
      setFormError(err.message || 'Error al guardar el menú semanal en Supabase.');
    } finally {
      setSubmitting(false);
    }
  };

  const activeDay = weekDays[activeDayIndex] || weekDays[0];
  const activeDayPlatos = selectedPlatosByDate[activeDay?.dateStr] || [];

  const hasExistingData = useMemo(() => {
    return weekDays.some((d) => {
      const m = menus.find((item) => item.fecha && item.fecha.split('T')[0] === d.dateStr);
      return m && (m.platos || []).length > 0;
    });
  }, [weekDays, menus]);

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={hasExistingData ? "Editar Menú de la Semana" : "Crear Menú Completo de la Semana"}
      subtitle={hasExistingData ? "Consulta y edita los platos asignados para cada día de la semana" : "Define los platos para cada día hábil en una sola inserción atómica"}
      icon={CalendarDays}
      maxWidth="max-w-4xl"
    >
      <form onSubmit={handleSaveWeekMenu} className="space-y-5">
        {formError && (
          <div className="p-3 bg-rose-50 border border-rose-200 rounded-xl text-rose-700 text-xs flex items-center space-x-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{formError}</span>
          </div>
        )}

        {/* Barra superior de configuración de la semana y estado del borrador */}
        <div className="bg-slate-50 border border-slate-200 rounded-2xl p-4 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-blue-100 text-blue-700 rounded-xl">
              <Calendar className="w-4 h-4" />
            </div>
            <div>
              <label className="block text-[11px] font-bold text-slate-700 uppercase">
                Semana a Programar
              </label>
              <input
                type="date"
                value={startMonday}
                onChange={handleMondayChange}
                className="bg-white border border-slate-300 rounded-lg px-2.5 py-1 text-xs font-semibold text-slate-800 focus:outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer"
                title="Selecciona cualquier día de la semana. Sábados o domingos saltan automáticamente al siguiente lunes."
              />
            </div>
            <div className="hidden sm:block">
              <span className="text-xs font-bold text-blue-800 bg-blue-100/70 px-2.5 py-1 rounded-lg border border-blue-200 inline-block">
                {weekDays[0]?.displayDate} al {weekDays[weekDays.length - 1]?.displayDate}
              </span>
              {hasExistingData && (
                <span className="ml-2 text-[10px] font-extrabold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-200">
                  Semana con menú cargado
                </span>
              )}
            </div>
          </div>

          {/* Indicador de guardado local / Descartar */}
          <div className="flex items-center space-x-2 text-xs">
            {draftSavedAt ? (
              <span className="inline-flex items-center text-[11px] font-medium text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-lg border border-emerald-200">
                <Save className="w-3 h-3 mr-1" />
                Cambios en borrador ({draftSavedAt})
              </span>
            ) : hasExistingData ? (
              <span className="inline-flex items-center text-[11px] font-medium text-blue-700 bg-blue-50 px-2.5 py-1 rounded-lg border border-blue-200">
                <Check className="w-3 h-3 mr-1" />
                Sincronizado con sistema
              </span>
            ) : (
              <span className="text-[11px] text-slate-400">Sin programación previa</span>
            )}
            <button
              type="button"
              onClick={handleClearDraft}
              className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
              title="Restaurar a datos originales del sistema"
            >
              <RotateCcw className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>

        {/* Pestañas de Días de la Semana (Lunes a Viernes) */}
        <div>
          <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-2">
            Selecciona el día para ver y asignar sus platos:
          </label>
          <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">
            {weekDays.map((d, idx) => {
              const count = (selectedPlatosByDate[d.dateStr] || []).length;
              const isActive = activeDayIndex === idx;

              return (
                <button
                  key={d.dateStr}
                  type="button"
                  onClick={() => setActiveDayIndex(idx)}
                  className={`p-3 rounded-xl border text-left transition relative flex flex-col justify-between ${
                    isActive
                      ? 'bg-blue-600 text-white border-blue-600 shadow-md ring-2 ring-blue-300'
                      : 'bg-white hover:bg-slate-50 border-slate-200 text-slate-700'
                  }`}
                >
                  <div>
                    <span className={`text-[10px] uppercase font-bold block ${isActive ? 'text-blue-100' : 'text-slate-400'}`}>
                      {d.dayName}
                    </span>
                    <span className="text-xs font-bold block">{d.displayDate}</span>
                  </div>
                  <div className="mt-2 flex items-center justify-between">
                    <span
                      className={`text-[10px] font-extrabold px-1.5 py-0.5 rounded-full ${
                        count > 0
                          ? isActive
                            ? 'bg-white/20 text-white'
                            : 'bg-emerald-100 text-emerald-800'
                          : isActive
                          ? 'bg-white/10 text-blue-200'
                          : 'bg-slate-100 text-slate-400'
                      }`}
                    >
                      {count} {count === 1 ? 'plato' : 'platos'}
                    </span>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Área de Selección de Platos para el Día Activo */}
        <div className="bg-slate-50/70 border border-slate-200 rounded-2xl p-4 space-y-3">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 border-b border-slate-200 pb-2">
            <div className="flex items-center space-x-2">
              <ChefHat className="w-4 h-4 text-blue-600" />
              <h4 className="text-sm font-bold text-slate-800">
                Platos para el {activeDay.dayName} ({activeDay.displayDate})
              </h4>
              <span className={`text-xs font-bold px-2.5 py-0.5 rounded-full ${
                activeDayPlatos.length > 0
                  ? 'bg-blue-100 text-blue-800'
                  : 'bg-slate-200 text-slate-600'
              }`}>
                {activeDayPlatos.length} seleccionados
              </span>
            </div>

            {/* Buscador de platos */}
            <div className="relative w-full sm:w-64">
              <Search className="w-3.5 h-3.5 text-slate-400 absolute left-2.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={searchPlato}
                onChange={(e) => setSearchPlato(e.target.value)}
                placeholder="Buscar plato en catálogo..."
                className="w-full pl-8 pr-3 py-1.5 bg-white border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>

          {/* Listado con Checkboxes de Platos */}
          {filteredPlatos.length === 0 ? (
            <div className="py-6 text-center text-slate-400 text-xs">
              No hay platos en el catálogo que coincidan con la búsqueda.
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-2.5 max-h-60 overflow-y-auto p-1">
              {filteredPlatos.map((plato) => {
                const isSelected = activeDayPlatos.some((id) => String(id) === String(plato.id_plato));

                return (
                  <div
                    key={plato.id_plato}
                    onClick={() => togglePlatoForActiveDay(plato.id_plato)}
                    className={`p-3 rounded-xl border cursor-pointer transition select-none flex items-start space-x-2.5 ${
                      isSelected
                        ? 'bg-blue-50/90 border-blue-400 text-blue-950 shadow-2xs ring-1 ring-blue-300'
                        : 'bg-white border-slate-200 hover:bg-slate-50 text-slate-700'
                    }`}
                  >
                    <input
                      type="checkbox"
                      checked={isSelected}
                      onChange={() => {}}
                      className="mt-0.5 rounded text-blue-600 focus:ring-blue-500 pointer-events-none"
                    />
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <p className="text-xs font-bold truncate">{plato.nombre}</p>
                        {isSelected && (
                          <span className="text-[10px] font-extrabold text-blue-700 bg-blue-100 px-1.5 py-0.2 rounded-full">
                            Asignado
                          </span>
                        )}
                      </div>
                      {plato.descripcion && (
                        <p className="text-[11px] text-slate-400 truncate mt-0.5">
                          {plato.descripcion}
                        </p>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Interruptor de publicación global para la semana */}
        <div className="bg-blue-50/60 border border-blue-200 rounded-xl p-3.5 flex items-center justify-between">
          <div className="flex items-center space-x-2.5">
            <Sparkles className="w-4 h-4 text-blue-600 flex-shrink-0" />
            <div>
              <p className="text-xs font-bold text-slate-800">
                Publicar menú para toda la semana
              </p>
              <p className="text-[11px] text-slate-500">
                Al activar, todos los días quedarán como "Publicado" para que los empleados los visualicen y reserven.
              </p>
            </div>
          </div>
          <label className="relative inline-flex items-center cursor-pointer">
            <input
              type="checkbox"
              checked={publicarSemana}
              onChange={(e) => setPublicarSemana(e.target.checked)}
              className="sr-only peer"
            />
            <div className="w-11 h-6 bg-slate-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-600"></div>
          </label>
        </div>

        {/* Botones de acción */}
        <div className="pt-2 flex items-center justify-end space-x-3 border-t border-slate-100">
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
            className="flex items-center space-x-2 px-6 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold rounded-xl shadow-md transition disabled:opacity-50"
          >
            {submitting ? (
              <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
            ) : (
              <>
                <Check className="w-4 h-4" />
                <span>{hasExistingData ? "Actualizar Menú de la Semana" : "Guardar Menú de la Semana"}</span>
              </>
            )}
          </button>
        </div>
      </form>
    </Modal>
  );
}
