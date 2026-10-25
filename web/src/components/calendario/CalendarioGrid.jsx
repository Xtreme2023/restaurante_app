import React, { useMemo } from 'react';
import { 
  ChevronLeft, 
  ChevronRight, 
  Calendar, 
  AlertCircle, 
  Plus, 
  Trash2, 
  Info 
} from 'lucide-react';

const WEEKDAYS = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

const MONTH_NAMES = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
];

export default function CalendarioGrid({
  currentMonth,
  onPrevMonth,
  onNextMonth,
  onToday,
  excepciones = [],
  isAdmin,
  onSelectDate,
  onDeleteExcepcion,
}) {
  const year = currentMonth.getFullYear();
  const month = currentMonth.getMonth();

  // Diccionario de excepciones por fecha string 'YYYY-MM-DD'
  const excepcionesMap = useMemo(() => {
    const map = new Map();
    excepciones.forEach((e) => {
      if (e.fecha) {
        // Normalizar fecha a YYYY-MM-DD
        const dateStr = e.fecha.split('T')[0];
        map.set(dateStr, e);
      }
    });
    return map;
  }, [excepciones]);

  const todayStr = useMemo(() => {
    const now = new Date();
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    const d = String(now.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }, []);

  // Construcción de la matriz de días del mes
  const calendarCells = useMemo(() => {
    const firstDayOfMonth = new Date(year, month, 1);
    const lastDayOfMonth = new Date(year, month + 1, 0);
    const daysInMonth = lastDayOfMonth.getDate();

    // 0 = Domingo, 1 = Lunes, ..., 6 = Sábado. Ajustamos para que Lunes = 0 y Domingo = 6
    const firstDayIndex = (firstDayOfMonth.getDay() + 6) % 7;

    const cells = [];

    // Días del mes anterior para relleno
    const prevMonthLastDay = new Date(year, month, 0).getDate();
    for (let i = firstDayIndex - 1; i >= 0; i--) {
      cells.push({
        dayNumber: prevMonthLastDay - i,
        isCurrentMonth: false,
        dateStr: null,
      });
    }

    // Días del mes actual
    for (let day = 1; day <= daysInMonth; day++) {
      const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      cells.push({
        dayNumber: day,
        isCurrentMonth: true,
        dateStr,
        isToday: dateStr === todayStr,
        excepcion: excepcionesMap.get(dateStr) || null,
      });
    }

    // Días del mes siguiente para completar la cuadrícula (múltiplo de 7)
    const remaining = 7 - (cells.length % 7);
    if (remaining < 7) {
      for (let i = 1; i <= remaining; i++) {
        cells.push({
          dayNumber: i,
          isCurrentMonth: false,
          dateStr: null,
        });
      }
    }

    return cells;
  }, [year, month, excepcionesMap, todayStr]);

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-200/80 overflow-hidden">
      {/* Calendar Header with Navigation */}
      <div className="p-4 sm:p-6 bg-slate-50 border-b border-slate-200/80 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div className="flex items-center space-x-3">
          <div className="p-2.5 bg-blue-100 text-blue-700 rounded-xl">
            <Calendar className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-xl font-bold text-slate-900 tracking-tight">
              {MONTH_NAMES[month]} {year}
            </h2>
            <p className="text-xs text-slate-500 font-medium">
              Calendario de días de atención y excepciones institucionales
            </p>
          </div>
        </div>

        <div className="flex items-center space-x-2">
          <button
            type="button"
            onClick={onToday}
            className="px-3 py-1.5 bg-white border border-slate-200 text-slate-700 hover:bg-slate-100 rounded-xl text-xs font-semibold shadow-2xs transition"
          >
            Hoy
          </button>
          <div className="flex items-center bg-white border border-slate-200 rounded-xl p-0.5 shadow-2xs">
            <button
              type="button"
              onClick={onPrevMonth}
              className="p-1.5 text-slate-600 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition"
              title="Mes anterior"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <button
              type="button"
              onClick={onNextMonth}
              className="p-1.5 text-slate-600 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition"
              title="Mes siguiente"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      {/* Weekday headers */}
      <div className="grid grid-cols-7 bg-slate-100/70 border-b border-slate-200 text-center text-xs font-bold text-slate-600 uppercase py-2.5">
        {WEEKDAYS.map((w, idx) => (
          <div key={w} className={idx >= 5 ? 'text-amber-700' : ''}>
            {w}
          </div>
        ))}
      </div>

      {/* Days Grid */}
      <div className="grid grid-cols-7 divide-x divide-y divide-slate-100">
        {calendarCells.map((cell, idx) => {
          if (!cell.isCurrentMonth) {
            return (
              <div
                key={`empty-${idx}`}
                className="min-h-[90px] sm:min-h-[110px] p-2 bg-slate-50/40 text-slate-300 text-xs font-medium select-none"
              >
                {cell.dayNumber}
              </div>
            );
          }

          const hasException = !!cell.excepcion;

          return (
            <div
              key={cell.dateStr}
              onClick={() => {
                if (hasException) {
                  onSelectDate?.(cell.dateStr, cell.excepcion);
                } else if (isAdmin) {
                  onSelectDate?.(cell.dateStr, null);
                }
              }}
              className={`min-h-[90px] sm:min-h-[110px] p-2 transition relative flex flex-col justify-between group ${
                hasException
                  ? 'bg-rose-50/70 hover:bg-rose-100/60 border-rose-200 cursor-pointer'
                  : isAdmin
                  ? 'hover:bg-slate-50 cursor-pointer'
                  : 'bg-white'
              }`}
            >
              {/* Day header */}
              <div className="flex items-center justify-between">
                <span
                  className={`text-xs font-bold w-6 h-6 flex items-center justify-center rounded-full ${
                    cell.isToday
                      ? 'bg-blue-600 text-white shadow-xs'
                      : hasException
                      ? 'text-rose-700 font-extrabold'
                      : 'text-slate-700'
                  }`}
                >
                  {cell.dayNumber}
                </span>

                {/* Exception Badge or Add Button */}
                {hasException ? (
                  <span className="inline-flex items-center text-[10px] font-extrabold px-1.5 py-0.5 rounded-md bg-rose-600 text-white shadow-2xs">
                    No Atención
                  </span>
                ) : (
                  isAdmin && (
                    <span className="opacity-0 group-hover:opacity-100 text-[10px] font-medium text-slate-400 p-1 hover:text-blue-600 transition">
                      <Plus className="w-3.5 h-3.5" />
                    </span>
                  )
                )}
              </div>

              {/* Day Body Content */}
              <div className="mt-1 flex-1">
                {hasException ? (
                  <div className="space-y-1">
                    <p className="text-[11px] font-semibold text-rose-800 line-clamp-2 leading-tight">
                      {cell.excepcion.motivo}
                    </p>
                    {isAdmin && (
                      <div className="pt-1 flex items-center justify-end">
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            onDeleteExcepcion?.(cell.excepcion);
                          }}
                          className="opacity-0 group-hover:opacity-100 p-1 text-rose-500 hover:text-rose-700 hover:bg-rose-200/50 rounded-md transition"
                          title="Eliminar excepción"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    )}
                  </div>
                ) : (
                  <div className="h-full flex items-end">
                    <span className="text-[10px] text-slate-300 font-medium hidden sm:inline">
                      Atención normal
                    </span>
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Legend Footer */}
      <div className="p-3.5 bg-slate-50 border-t border-slate-200/80 flex flex-wrap items-center justify-between text-xs text-slate-600 gap-2">
        <div className="flex items-center space-x-4">
          <div className="flex items-center space-x-1.5">
            <span className="w-3 h-3 rounded-full bg-rose-600 inline-block" />
            <span className="font-medium">Día de No Atención (Excepción)</span>
          </div>
          <div className="flex items-center space-x-1.5">
            <span className="w-3 h-3 rounded-full bg-blue-600 inline-block" />
            <span className="font-medium">Hoy</span>
          </div>
          <div className="flex items-center space-x-1.5">
            <span className="w-3 h-3 rounded-full bg-white border border-slate-300 inline-block" />
            <span className="font-medium">Servicio Normal de Comedor</span>
          </div>
        </div>

        {isAdmin ? (
          <p className="text-[13px] text-slate-400 italic">
            * Haga clic en cualquier día para registrar un día sin atención.
          </p>
        ) : (
          <p className="text-[13px] text-slate-500 flex items-center space-x-1">
            <Info className="w-3.5 h-3.5 text-blue-600" />
            <span>Los días marcados no se brindará atención.</span>
          </p>
        )}
      </div>
    </div>
  );
}
