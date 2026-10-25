import React, { useState, useEffect, useCallback } from 'react';
import { useAuth } from '../context/AuthContext';
import { 
  platosService, 
  menuDiaService 
} from '../lib/menu';
import { getMondayOfWeek } from '../lib/dateUtils';
import { 
  UtensilsCrossed, 
  CalendarDays, 
  ChefHat, 
  CheckCircle2, 
  RefreshCw 
} from 'lucide-react';

import MenuSemanalView from './menu/MenuSemanalView';
import MenuSemanalModal from './menu/MenuSemanalModal';
import PlatosCatalogo from './menu/PlatosCatalogo';

export default function CrearMenu() {
  const { isAdmin } = useAuth();

  // Pestaña activa para el administrador: 'menu' (Menú Semanal) o 'platos' (Catálogo de Platos)
  const [activeTab, setActiveTabState] = useState(() => {
    return localStorage.getItem('crearmenu_active_subtab') || 'menu';
  });

  const setActiveTab = (tab) => {
    setActiveTabState(tab);
    localStorage.setItem('crearmenu_active_subtab', tab);
  };

  // Estados de datos sincronizados con Supabase
  const [platos, setPlatos] = useState([]);
  const [menus, setMenus] = useState([]);
  const [loading, setLoading] = useState(true);
  const [toastMessage, setToastMessage] = useState(null);

  // Modal para la creación / edición semanal completa
  const [isWeekModalOpen, setIsWeekModalOpen] = useState(false);
  const [selectedWeekMonday, setSelectedWeekMonday] = useState(() => getMondayOfWeek());
  const [selectedDayIndex, setSelectedDayIndex] = useState(0);

  const showToast = (message) => {
    setToastMessage(message);
    setTimeout(() => setToastMessage(null), 4000);
  };

  // Cargar platos y menús desde Supabase
  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [platosData, menusData] = await Promise.all([
        platosService.getPlatos(),
        menuDiaService.getMenuDiasConPlatos(),
      ]);

      setPlatos(platosData || []);
      setMenus(menusData || []);
    } catch (err) {
      console.error('Error al cargar datos desde Supabase:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 bg-slate-900 text-white px-5 py-3.5 rounded-2xl shadow-xl flex items-center space-x-3 border border-slate-700 animate-fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
          <span className="text-sm font-medium">{toastMessage}</span>
        </div>
      )}

      {/* Header Principal */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 bg-white p-6 rounded-2xl shadow-sm border border-slate-200/80">
        <div className="flex items-center space-x-3">
          <div className="p-2.5 bg-blue-50 rounded-xl text-blue-600">
            <UtensilsCrossed className="w-6 h-6" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-slate-900 tracking-tight">
              {isAdmin ? 'Gestión de Menús y Catálogo de Platos' : 'Menú Semanal de Almuerzos'}
            </h1>
            <p className="text-slate-500 text-sm mt-0.5">
              {isAdmin
                ? 'Crea menús completos para toda la semana y administra el catálogo de platos disponibles.'
                : 'Consulta la programación semanal de almuerzos para planificar tus reservas institucionales.'}
            </p>
          </div>
        </div>

        <div className="flex items-center space-x-3">
          <button
            type="button"
            onClick={loadData}
            disabled={loading}
            className="p-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-600 transition shadow-xs"
            title="Refrescar datos"
          >
            <RefreshCw className={`w-5 h-5 ${loading ? 'animate-spin text-blue-600' : ''}`} />
          </button>
        </div>
      </div>

      {/* Pestañas para el Administrador */}
      {isAdmin && (
        <div className="flex items-center space-x-2 border-b border-slate-200 pb-1">
          <button
            type="button"
            onClick={() => setActiveTab('menu')}
            className={`flex items-center space-x-2 px-4 py-2.5 rounded-xl font-semibold text-sm transition-all duration-200 ${
              activeTab === 'menu'
                ? 'bg-blue-600 text-white shadow-md'
                : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
            }`}
          >
            <CalendarDays className="w-4 h-4" />
            <span>Programación Semanal ({menus.length} días)</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('platos')}
            className={`flex items-center space-x-2 px-4 py-2.5 rounded-xl font-semibold text-sm transition-all duration-200 ${
              activeTab === 'platos'
                ? 'bg-blue-600 text-white shadow-md'
                : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
            }`}
          >
            <ChefHat className="w-4 h-4" />
            <span>Catálogo de Platos ({platos.length})</span>
          </button>
        </div>
      )}

      {/* Vista de Menú Semanal (Administrador o Empleado) */}
      {(activeTab === 'menu' || !isAdmin) && (
        <MenuSemanalView
          menus={menus}
          isAdmin={isAdmin}
          onOpenCreateWeekModal={(weekMonday, dayIdx = 0) => {
            if (weekMonday) setSelectedWeekMonday(weekMonday);
            setSelectedDayIndex(dayIdx);
            setIsWeekModalOpen(true);
          }}
          onRefresh={loadData}
          loading={loading}
        />
      )}

      {/* Vista de Catálogo de Platos (Solo Administrador) */}
      {isAdmin && activeTab === 'platos' && (
        <PlatosCatalogo
          platos={platos}
          onRefresh={loadData}
          showToast={showToast}
        />
      )}

      {/* Modal: Creación / Edición Semanal Completa con sincronización de datos existentes */}
      {isAdmin && (
        <MenuSemanalModal
          isOpen={isWeekModalOpen}
          onClose={() => setIsWeekModalOpen(false)}
          platos={platos}
          menus={menus}
          initialMonday={selectedWeekMonday}
          initialDayIndex={selectedDayIndex}
          onMenuCreated={loadData}
          showToast={showToast}
        />
      )}
    </div>
  );
}
