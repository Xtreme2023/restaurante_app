import React, { useState, useMemo } from 'react';
import { 
  ChevronLeft, 
  ChevronRight, 
  Calendar, 
  ChefHat, 
  Clock, 
  AlertCircle, 
  CheckCircle2, 
  UtensilsCrossed,
  Sparkles,
  CalendarPlus
} from 'lucide-react';

import { 
  getMondayOfWeek, 
  generateWeekDays, 
  formatLocalDate, 
  parseLocalDate 
} from '../../lib/dateUtils';

export default function MenuSemanalView({
  menus = [],
  isAdmin,
  onOpenCreateWeekModal,
  onRefresh,
  loading,
}) {
  const [selectedMonday, setSelectedMonday] = useState(() => getMondayOfWeek(new Date()));

  // Navegación de semana con cálculos de fecha local segura
  const handlePrevWeek = () => {
    const monday = parseLocalDate(selectedMonday);
    monday.setDate(monday.getDate() - 7);
    setSelectedMonday(formatLocalDate(monday));
  };

  const handleNextWeek = () => {
    const monday = parseLocalDate(selectedMonday);
    monday.setDate(monday.getDate() + 7);
    setSelectedMonday(formatLocalDate(monday));
  };

  const handleCurrentWeek = () => {
    setSelectedMonday(getMondayOfWeek(new Date()));
  };

  const weekDays = useMemo(() => generateWeekDays(selectedMonday), [selectedMonday]);

  // Mapear menús existentes por fecha
  const menusByDate = useMemo(() => {
    const map = new Map();
    menus.forEach((m) => {
      if (m.fecha) {
        map.set(m.fecha.split('T')[0], m);
      }
    });
    return map;
  }, [menus]);

  // Comprobar estado de la semana para HU5
  const weekStats = useMemo(() => {
    let publishedDays = 0;
    let totalMenus = 0;

    weekDays.forEach((d) => {
      const m = menusByDate.get(d.dateStr);
      if (m) {
        totalMenus++;
        if (m.estado_publicacion === true || m.estado_publicacion === 'Publicado') {
          publishedDays++;
        }
      }
    });

    return {
      totalMenus,
      publishedDays,
      isFullyPublished: publishedDays === 5,
      hasPublishedMenu: publishedDays > 0,
    };
  }, [weekDays, menusByDate]);

  // HU5: Comprobar si ya pasó la fecha/hora de restricción (ej. Viernes 08:30)
  const isPastWeeklyDeadline = useMemo(() => {
    const now = new Date();
    const friday = weekDays[4]?.dateObj;
    if (!friday) return false;

    // Crear fecha límite: Viernes a las 08:30 AM
    const deadline = new Date(friday);
    deadline.setHours(8, 30, 0, 0);

    return now > deadline;
  }, [weekDays]);

  const todayStr = useMemo(() => formatLocalDate(new Date()), []);

  return (
    <div className="space-y-6">
      {/* Barra de Navegación Semanal */}
      <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/80 shadow-sm flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div className="flex items-center space-x-3">
          <div className="p-2.5 bg-blue-50 text-blue-600 rounded-xl">
            <Calendar className="w-5 h-5" />
          </div>
          <div>
            <span className="text-xs font-bold text-slate-400 uppercase tracking-wider block">
              Programación Semanal
            </span>
            <h2 className="text-lg font-bold text-slate-900">
              Semana del {weekDays[0]?.displayDate} al {weekDays[4]?.displayDate}
            </h2>
          </div>
        </div>

        {/* Controles de semana */}
        <div className="flex items-center space-x-2">
          <button
            type="button"
            onClick={handleCurrentWeek}
            className="px-3 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-semibold transition"
          >
            Semana Actual
          </button>
          <div className="flex items-center bg-slate-100 rounded-xl p-0.5 border border-slate-200">
            <button
              type="button"
              onClick={handlePrevWeek}
              className="p-1.5 text-slate-600 hover:text-slate-900 hover:bg-white rounded-lg transition"
              title="Semana anterior"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <button
              type="button"
              onClick={handleNextWeek}
              className="p-1.5 text-slate-600 hover:text-slate-900 hover:bg-white rounded-lg transition"
              title="Semana siguiente"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>

          {isAdmin && (
            <button
              type="button"
              onClick={() => onOpenCreateWeekModal?.(selectedMonday, 0)}
              className="flex items-center space-x-1.5 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold px-4 py-2 rounded-xl text-xs shadow-md transition transform active:scale-95"
            >
              <CalendarPlus className="w-4 h-4" />
              <span>Programar Semana Completa</span>
            </button>
          )}
        </div>
      </div>

      {/* HU5: Banner de Información para Empleados */}
      {!isAdmin && (
        <div className="bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-2xl p-4 flex items-center justify-between shadow-xs">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-blue-600 text-white rounded-xl flex-shrink-0">
              <Sparkles className="w-4 h-4" />
            </div>
            <div>
              <p className="text-xs font-bold text-blue-950">
                Reglas de Visualización y Reserva (HU5)
              </p>
              <p className="text-[11px] text-blue-700/90 mt-0.5">
                Los menús son publicados los domingos para toda la semana. Las reservas están disponibles hasta el viernes 08:30 AM.
              </p>
            </div>
          </div>
          {isPastWeeklyDeadline ? (
            <span className="text-[11px] font-bold text-rose-700 bg-rose-50 px-3 py-1 rounded-full border border-rose-200 flex-shrink-0">
              Semana cerrada (Fuera de horario)
            </span>
          ) : (
            <span className="text-[11px] font-bold text-emerald-700 bg-emerald-50 px-3 py-1 rounded-full border border-emerald-200 flex-shrink-0">
              Reservas abiertas
            </span>
          )}
        </div>
      )}

      {/* HU5: Caso error cuando no hay menú cargado o publicado */}
      {!isAdmin && !weekStats.hasPublishedMenu ? (
        <div className="bg-white rounded-2xl p-12 text-center border border-slate-200/80 shadow-sm space-y-3">
          <div className="w-14 h-14 bg-amber-50 text-amber-600 rounded-2xl flex items-center justify-center mx-auto border border-amber-200/60">
            <AlertCircle className="w-7 h-7" />
          </div>
          <h3 className="text-lg font-bold text-slate-800">Menú no disponible</h3>
          <p className="text-xs text-slate-500 max-w-md mx-auto">
            Actualmente el administrador no ha publicado el menú para la semana del {weekDays[0]?.displayDate} al {weekDays[4]?.displayDate}. Por favor consulta más tarde cuando se habilite la publicación.
          </p>
        </div>
      ) : (
        /* Cuadrícula de 5 Tarjetas Diarias (Lunes a Viernes) */
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
          {weekDays.map((d) => {
            const menu = menusByDate.get(d.dateStr);
            const isToday = d.dateStr === todayStr;
            const isPublicado = menu && (menu.estado_publicacion === true || menu.estado_publicacion === 'Publicado');
            const platosList = menu?.platos || [];

            // Si es empleado y el menú no está publicado, ocultar platos
            if (!isAdmin && !isPublicado) {
              return (
                <div
                  key={d.dateStr}
                  className="bg-white rounded-2xl border border-dashed border-slate-200 p-4 flex flex-col justify-between opacity-60 min-h-[220px]"
                >
                  <div className="border-b border-slate-100 pb-2">
                    <span className="text-xs font-bold text-slate-400 uppercase">{d.dayName}</span>
                    <p className="text-sm font-bold text-slate-700">{d.displayDate}</p>
                  </div>
                  <div className="py-6 text-center text-slate-400 text-xs">
                    Sin menú publicado
                  </div>
                </div>
              );
            }

            return (
              <div
                key={d.dateStr}
                className={`bg-white rounded-2xl border transition-all shadow-xs flex flex-col justify-between ${
                  isToday
                    ? 'border-blue-400 ring-2 ring-blue-100 shadow-md'
                    : 'border-slate-200/80 hover:shadow-sm'
                }`}
              >
                {/* Cabecera del día */}
                <div className={`p-4 rounded-t-2xl border-b ${
                  isToday ? 'bg-blue-50/70 border-blue-200' : 'bg-slate-50/60 border-slate-100'
                }`}>
                  <div className="flex items-center justify-between">
                    <span className={`text-[11px] font-bold uppercase tracking-wider ${
                      isToday ? 'text-blue-700' : 'text-slate-500'
                    }`}>
                      {d.dayName}
                    </span>
                    <div className="flex items-center space-x-1.5">
                      {isToday && (
                        <span className="text-[10px] font-extrabold bg-blue-600 text-white px-2 py-0.5 rounded-full">
                          Hoy
                        </span>
                      )}
                      {isAdmin && (
                        <button
                          type="button"
                          onClick={() => onOpenCreateWeekModal?.(selectedMonday, d.index)}
                          className="text-[10px] font-bold text-blue-600 hover:text-blue-800 hover:underline px-1 py-0.5 rounded hover:bg-blue-50 transition"
                          title={`Editar platos del ${d.dayName}`}
                        >
                          Editar
                        </button>
                      )}
                    </div>
                  </div>
                  <h3 className="text-base font-extrabold text-slate-900 mt-0.5">
                    {d.displayDate}
                  </h3>

                  {/* Badge de Publicación (para Admin) */}
                  {isAdmin && (
                    <div className="mt-2">
                      {menu ? (
                        isPublicado ? (
                          <span className="inline-flex items-center text-[10px] font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-200">
                            <CheckCircle2 className="w-3 h-3 mr-1" /> Publicado
                          </span>
                        ) : (
                          <span className="inline-flex items-center text-[10px] font-bold text-amber-700 bg-amber-50 px-2 py-0.5 rounded-md border border-amber-200">
                            Borrador
                          </span>
                        )
                      ) : (
                        <span className="text-[10px] font-semibold text-slate-400">
                          No programado
                        </span>
                      )}
                    </div>
                  )}
                </div>

                {/* Lista de Platos asignados */}
                <div className="p-4 flex-1 space-y-2">
                  {!menu || platosList.length === 0 ? (
                    <div className="py-8 text-center text-slate-400 text-xs flex flex-col items-center justify-center h-full">
                      <ChefHat className="w-6 h-6 text-slate-300 mb-1" />
                      <span>Sin platos asignados</span>
                    </div>
                  ) : (
                    <div className="space-y-2">
                      {platosList.map((p) => (
                        <div
                          key={p.id_plato}
                          className="p-2.5 bg-slate-50 hover:bg-slate-100/70 rounded-xl border border-slate-100 transition text-xs"
                        >
                          <div className="flex items-start space-x-2.5">
                            {p.imagen_url ? (
                              <img
                                src={p.imagen_url}
                                alt={p.nombre}
                                className="w-9 h-9 rounded-lg object-cover flex-shrink-0 border border-slate-200 shadow-xs"
                                loading="lazy"
                                onError={(e) => {
                                  e.currentTarget.style.display = 'none';
                                }}
                              />
                            ) : (
                              <UtensilsCrossed className="w-3.5 h-3.5 text-blue-600 mt-0.5 flex-shrink-0" />
                            )}
                            <div className="min-w-0">
                              <p className="font-bold text-slate-800 leading-tight truncate">
                                {p.nombre}
                              </p>
                              {p.descripcion && (
                                <p className="text-[11px] text-slate-500 mt-0.5 line-clamp-2">
                                  {p.descripcion}
                                </p>
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* Pie de tarjeta con conteo */}
                <div className="p-3 bg-slate-50/50 rounded-b-2xl border-t border-slate-100 text-right">
                  <span className="text-[11px] text-slate-500 font-medium">
                    {platosList.length} {platosList.length === 1 ? 'opción' : 'opciones'}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
