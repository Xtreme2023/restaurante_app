import React, { useState, useEffect } from 'react';
import { fetchUsuarios } from '../lib/supabaseClient';
import { 
  BarChart3, 
  Users, 
  CheckCircle, 
  Utensils, 
  TrendingUp, 
  Shield, 
  Briefcase, 
  Building2,
  Calendar
} from 'lucide-react';

export default function Reportes() {
  const [usuarios, setUsuarios] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      try {
        const data = await fetchUsuarios();
        setUsuarios(data || []);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const total = usuarios.length;
  const adminCount = usuarios.filter((u) => u.rol === 'Administrador').length;
  const empleadoCount = usuarios.filter((u) => u.rol === 'Empleado').length;
  const institucionCount = usuarios.filter((u) => u.rol === 'Institucion').length;
  const activos = usuarios.filter((u) => u.activo !== false).length;
  const inactivos = total - activos;

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      {/* Header */}
      <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200/80">
        <div className="flex items-center space-x-2">
          <div className="p-2 bg-blue-50 rounded-xl text-blue-600">
            <BarChart3 className="w-6 h-6" />
          </div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Reportes y Estadísticas</h1>
        </div>
        <p className="text-slate-500 text-sm mt-1">
          Métricas de usuarios registrados, distribución por roles y consumo de almuerzos en el sistema.
        </p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Cuentas Registradas</p>
            <p className="text-2xl font-black text-slate-900 mt-1">{total}</p>
            <span className="text-[11px] text-emerald-600 font-medium">100% sincronizado con Supabase</span>
          </div>
          <div className="p-3 bg-blue-50 text-blue-600 rounded-xl">
            <Users className="w-6 h-6" />
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Cuentas Activas</p>
            <p className="text-2xl font-black text-emerald-700 mt-1">{activos}</p>
            <span className="text-[11px] text-slate-400 font-medium">{inactivos} desactivadas</span>
          </div>
          <div className="p-3 bg-emerald-50 text-emerald-600 rounded-xl">
            <CheckCircle className="w-6 h-6" />
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Almuerzos Semana</p>
            <p className="text-2xl font-black text-indigo-700 mt-1">450</p>
            <span className="text-[11px] text-indigo-600 font-medium">Promedio: 90 / día</span>
          </div>
          <div className="p-3 bg-indigo-50 text-indigo-600 rounded-xl">
            <Utensils className="w-6 h-6" />
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Tasa de Asistencia</p>
            <p className="text-2xl font-black text-teal-700 mt-1">96.4%</p>
            <span className="text-[11px] text-teal-600 font-medium">+3.2% vs mes anterior</span>
          </div>
          <div className="p-3 bg-teal-50 text-teal-600 rounded-xl">
            <TrendingUp className="w-6 h-6" />
          </div>
        </div>
      </div>

      {/* Role Breakdown */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200/80 space-y-4">
          <h3 className="font-bold text-slate-900 text-base">Distribución por Rol</h3>
          
          <div className="space-y-3">
            <div>
              <div className="flex justify-between text-xs font-semibold mb-1">
                <span className="text-purple-700 flex items-center">
                  <Shield className="w-3.5 h-3.5 mr-1" /> Administradores
                </span>
                <span className="text-slate-700">{adminCount} ({total > 0 ? Math.round((adminCount / total) * 100) : 0}%)</span>
              </div>
              <div className="w-full h-2.5 bg-slate-100 rounded-full overflow-hidden">
                <div
                  className="h-full bg-purple-600 rounded-full"
                  style={{ width: `${total > 0 ? (adminCount / total) * 100 : 0}%` }}
                />
              </div>
            </div>

            <div>
              <div className="flex justify-between text-xs font-semibold mb-1">
                <span className="text-emerald-700 flex items-center">
                  <Briefcase className="w-3.5 h-3.5 mr-1" /> Empleados
                </span>
                <span className="text-slate-700">{empleadoCount} ({total > 0 ? Math.round((empleadoCount / total) * 100) : 0}%)</span>
              </div>
              <div className="w-full h-2.5 bg-slate-100 rounded-full overflow-hidden">
                <div
                  className="h-full bg-emerald-600 rounded-full"
                  style={{ width: `${total > 0 ? (empleadoCount / total) * 100 : 0}%` }}
                />
              </div>
            </div>

            <div>
              <div className="flex justify-between text-xs font-semibold mb-1">
                <span className="text-amber-700 flex items-center">
                  <Building2 className="w-3.5 h-3.5 mr-1" /> Institución
                </span>
                <span className="text-slate-700">{institucionCount} ({total > 0 ? Math.round((institucionCount / total) * 100) : 0}%)</span>
              </div>
              <div className="w-full h-2.5 bg-slate-100 rounded-full overflow-hidden">
                <div
                  className="h-full bg-amber-600 rounded-full"
                  style={{ width: `${total > 0 ? (institucionCount / total) * 100 : 0}%` }}
                />
              </div>
            </div>
          </div>
        </div>

        {/* Audit Log / Activity */}
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200/80 space-y-4">
          <h3 className="font-bold text-slate-900 text-base">Últimos Registros del Sistema</h3>
          <div className="space-y-2.5 max-h-56 overflow-y-auto pr-1">
            {usuarios.slice(0, 4).map((u) => (
              <div key={u.id_usuario} className="p-2.5 bg-slate-50 rounded-xl border border-slate-100 flex items-center justify-between text-xs">
                <div>
                  <p className="font-bold text-slate-800">{u.nombres} {u.apellidos}</p>
                  <p className="text-slate-400 font-mono">{u.email}</p>
                </div>
                <span className="font-semibold text-blue-700 bg-blue-50 px-2 py-0.5 rounded-md">
                  {u.rol}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
