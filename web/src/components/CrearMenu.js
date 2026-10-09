import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { 
  UtensilsCrossed, 
  CalendarPlus, 
  Calendar, 
  Check, 
  X, 
  Sparkles,
  ChefHat,
  Plus
} from 'lucide-react';

const INITIAL_MENU = [
  { fecha: '12/10/2026', dia: 'Lunes', almuerzo: 'Pollo a la plancha con ensalada fresca', estado: 'Normal' },
  { fecha: '13/10/2026', dia: 'Martes', almuerzo: 'Feriado Institucional', estado: 'Feriado' },
  { fecha: '14/10/2026', dia: 'Miércoles', almuerzo: 'Carne asada con papas doradas', estado: 'Normal' },
  { fecha: '15/10/2026', dia: 'Jueves', almuerzo: 'Lasaña de verduras con queso gratinado', estado: 'Normal' },
  { fecha: '16/10/2026', dia: 'Viernes', almuerzo: 'Arroz con pollo y ensalada de zanahoria', estado: 'Normal' },
];

export default function CrearMenu() {
  const { isAdmin } = useAuth();
  const [menuList, setMenuList] = useState(INITIAL_MENU);
  const [showModal, setShowModal] = useState(false);

  const [mes, setMes] = useState('10');
  const [semana, setSemana] = useState('1');
  const [diasItems, setDiasItems] = useState([
    { dia: 'Lunes', fecha: '1/10/2026', almuerzo: '' },
    { dia: 'Martes', fecha: '2/10/2026', almuerzo: '' },
    { dia: 'Miércoles', fecha: '3/10/2026', almuerzo: '' },
    { dia: 'Jueves', fecha: '4/10/2026', almuerzo: '' },
    { dia: 'Viernes', fecha: '5/10/2026', almuerzo: '' },
  ]);

  const updateDias = (selectedSemana, selectedMes) => {
    if (!selectedSemana || !selectedMes) return;
    const s = parseInt(selectedSemana, 10);
    const m = selectedMes;
    const inicio = (s - 1) * 7 + 1;
    const diasNombres = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

    const newDias = diasNombres.map((dia, index) => ({
      dia,
      fecha: `${inicio + index}/${m}/2026`,
      almuerzo: diasItems[index]?.almuerzo || '',
    }));
    setDiasItems(newDias);
  };

  const handleSemanaChange = (e) => {
    const val = e.target.value;
    setSemana(val);
    updateDias(val, mes);
  };

  const handleMesChange = (e) => {
    const val = e.target.value;
    setMes(val);
    updateDias(semana, val);
  };

  const handleAlmuerzoChange = (index, value) => {
    setDiasItems((prev) => {
      const copy = [...prev];
      copy[index].almuerzo = value;
      return copy;
    });
  };

  const handleSaveMenu = (e) => {
    e.preventDefault();
    const formatted = diasItems.map((item) => ({
      fecha: item.fecha,
      dia: item.dia,
      almuerzo: item.almuerzo || 'Almuerzo ejecutivo especial',
      estado: item.almuerzo?.toLowerCase().includes('feriado') ? 'Feriado' : 'Normal',
    }));
    setMenuList(formatted);
    setShowModal(false);
  };

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 bg-white p-6 rounded-2xl shadow-sm border border-slate-200/80">
        <div>
          <div className="flex items-center space-x-2">
            <div className="p-2 bg-blue-50 rounded-xl text-blue-600">
              <UtensilsCrossed className="w-6 h-6" />
            </div>
            <h1 className="text-2xl font-bold text-slate-900 tracking-tight">
              {isAdmin ? 'Creación de Menú Semanal' : 'Programación del Menú Semanal'}
            </h1>
          </div>
          <p className="text-slate-500 text-sm mt-1">
            Cronograma de almuerzos nutritivos programados para la semana.
          </p>
        </div>

        {isAdmin && (
          <button
            onClick={() => {
              updateDias(semana, mes);
              setShowModal(true);
            }}
            className="flex items-center space-x-2 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold px-4 py-2.5 rounded-xl shadow-md transition transform active:scale-95"
          >
            <CalendarPlus className="w-5 h-5" />
            <span>Crear Menú Semanal</span>
          </button>
        )}
      </div>

      {/* Main Table Card matching menu.html */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200/80 overflow-hidden">
        <div className="bg-gradient-to-r from-blue-700 to-indigo-700 text-white px-6 py-4 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <ChefHat className="w-5 h-5 text-blue-200" />
            <h3 className="font-bold text-lg">Menú Semanal de Almuerzos</h3>
          </div>
          <span className="text-xs font-semibold bg-white/20 px-3 py-1 rounded-full">
            Octubre 2026
          </span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-center border-collapse">
            <thead>
              <tr className="bg-blue-50/70 border-b border-blue-100 text-blue-900 text-xs uppercase font-bold tracking-wider">
                <th className="py-3.5 px-6">Fecha</th>
                <th className="py-3.5 px-6">Día</th>
                <th className="py-3.5 px-6 text-left">Almuerzo Planificado</th>
                <th className="py-3.5 px-6">Estado</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-sm text-slate-700">
              {menuList.map((item, index) => {
                const isFeriado = item.estado === 'Feriado';
                return (
                  <tr key={index} className="hover:bg-slate-50 transition">
                    <td className="py-4 px-6 font-mono font-medium text-slate-600">
                      {item.fecha}
                    </td>
                    <td className="py-4 px-6 font-semibold text-slate-800">
                      {item.dia}
                    </td>
                    <td className="py-4 px-6 text-left">
                      <span className={`font-medium ${isFeriado ? 'text-amber-600 font-bold italic' : 'text-slate-900'}`}>
                        {item.almuerzo}
                      </span>
                    </td>
                    <td className="py-4 px-6">
                      {isFeriado ? (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-amber-100 text-amber-800 border border-amber-200">
                          Feriado
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-emerald-100 text-emerald-800 border border-emerald-200">
                          Programado
                        </span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal: Crear Menú para la Próxima Semana matching menu.html */}
      {showModal && (
        <div className="fixed inset-0 z-50 overflow-y-auto bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="relative w-full max-w-2xl bg-white rounded-2xl shadow-2xl overflow-hidden animate-fade-in-up border border-slate-100">
            {/* Modal Header */}
            <div className="bg-gradient-to-r from-blue-700 to-indigo-700 text-white p-5 flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <CalendarPlus className="w-6 h-6 text-blue-200" />
                <h3 className="text-lg font-bold">Crear Menú para la Próxima Semana</h3>
              </div>
              <button
                onClick={() => setShowModal(false)}
                className="text-white/80 hover:text-white p-1 rounded-lg hover:bg-white/10"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Form */}
            <form onSubmit={handleSaveMenu} className="p-6 space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                    Mes
                  </label>
                  <select
                    value={mes}
                    onChange={handleMesChange}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="10">Octubre</option>
                    <option value="11">Noviembre</option>
                    <option value="12">Diciembre</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                    Semana
                  </label>
                  <select
                    value={semana}
                    onChange={handleSemanaChange}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="1">Primera semana</option>
                    <option value="2">Segunda semana</option>
                    <option value="3">Tercera semana</option>
                    <option value="4">Cuarta semana</option>
                  </select>
                </div>
              </div>

              {/* Dynamic meal inputs for each day */}
              <div className="space-y-3 pt-2">
                <h4 className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Almuerzos por Día
                </h4>
                {diasItems.map((item, idx) => (
                  <div key={idx} className="grid grid-cols-1 sm:grid-cols-3 gap-2 items-center bg-slate-50 p-2.5 rounded-xl border border-slate-200">
                    <span className="font-semibold text-xs text-slate-700">
                      {item.dia} ({item.fecha})
                    </span>
                    <input
                      type="text"
                      value={item.almuerzo}
                      onChange={(e) => handleAlmuerzoChange(idx, e.target.value)}
                      placeholder="Plato del día o Feriado..."
                      required
                      className="sm:col-span-2 px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                ))}
              </div>

              <div className="pt-3 flex items-center justify-end space-x-3">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100 rounded-xl"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold rounded-xl shadow-md transition"
                >
                  Guardar Menú
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
