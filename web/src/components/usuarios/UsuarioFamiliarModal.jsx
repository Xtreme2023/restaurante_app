import React, { useState, useEffect, useCallback } from 'react';
import Modal from '../Modal';
import { 
  fetchFamiliaresByUsuario, 
  createFamiliar, 
  deleteFamiliar 
} from '../../lib/supabaseClient';
import { 
  Users, 
  UserPlus, 
  Trash2, 
  AlertCircle, 
  Check, 
  Phone, 
  User, 
  Heart,
  Briefcase
} from 'lucide-react';

const PARENTESCOS = ['Esposa', 'Esposo', 'Hijo', 'Hija'];

/**
 * Modal para ver y registrar familiares de usuarios con rol 'Empleado'
 * Reutiliza el componente general Modal
 */
export default function UsuarioFamiliarModal({
  isOpen,
  onClose,
  employee,
  employees = [],
  showToast,
}) {
  const [selectedEmpId, setSelectedEmpId] = useState(employee?.id_usuario || '');
  const [familiares, setFamiliares] = useState([]);
  const [loadingList, setLoadingList] = useState(false);

  // Form state
  const [formData, setFormData] = useState({
    parentesco: 'Hijo',
    nombre: '',
    apellidos: '',
    telefono: '',
  });
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState(null);
  const [deletingId, setDeletingId] = useState(null);

  // Actualizar empleado seleccionado cuando cambia la prop
  useEffect(() => {
    if (employee?.id_usuario) {
      setSelectedEmpId(employee.id_usuario);
    } else if (employees.length > 0 && !selectedEmpId) {
      setSelectedEmpId(employees[0].id_usuario);
    }
  }, [employee, employees, selectedEmpId]);

  // Cargar lista de familiares del empleado seleccionado
  const loadFamiliares = useCallback(async () => {
    if (!selectedEmpId) return;
    try {
      setLoadingList(true);
      const data = await fetchFamiliaresByUsuario(selectedEmpId);
      setFamiliares(data || []);
    } catch (err) {
      console.error('Error cargando familiares:', err);
    } finally {
      setLoadingList(false);
    }
  }, [selectedEmpId]);

  useEffect(() => {
    if (isOpen && selectedEmpId) {
      loadFamiliares();
    }
  }, [isOpen, selectedEmpId, loadFamiliares]);

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleCreateSubmit = async (e) => {
    e.preventDefault();
    setFormError(null);

    if (!selectedEmpId) {
      setFormError('Debe seleccionar a un empleado.');
      return;
    }
    if (!formData.nombre.trim()) {
      setFormError('El nombre del familiar es obligatorio.');
      return;
    }
    if (!formData.apellidos.trim()) {
      setFormError('Los apellidos del familiar son obligatorios.');
      return;
    }

    try {
      setSubmitting(true);
      await createFamiliar({
        id_usuario: selectedEmpId,
        parentesco: formData.parentesco,
        nombre: formData.nombre,
        apellidos: formData.apellidos,
        telefono: formData.telefono,
      });

      showToast?.(`Familiar (${formData.parentesco}) registrado exitosamente.`);
      setFormData({
        parentesco: 'Hijo',
        nombre: '',
        apellidos: '',
        telefono: '',
      });
      await loadFamiliares();
    } catch (err) {
      console.error('Error al registrar familiar:', err);
      setFormError(err.message || 'Error al guardar el familiar.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async (familiar) => {
    if (!window.confirm(`¿Deseas desvincular a este familiar (${familiar.parentesco})?`)) {
      return;
    }
    try {
      setDeletingId(familiar.id_persona);
      await deleteFamiliar(familiar.id_persona, selectedEmpId);
      showToast?.('Familiar desvinculado correctamente.');
      setFamiliares((prev) => prev.filter((f) => f.id_persona !== familiar.id_persona));
    } catch (err) {
      console.error('Error al eliminar familiar:', err);
      alert('Error al desvincular familiar.');
    } finally {
      setDeletingId(null);
    }
  };

  const currentEmployee = employees.find((e) => e.id_usuario === selectedEmpId) || employee;
  const currentEmployeeName = currentEmployee
    ? currentEmployee.nombre_completo || `${currentEmployee.nombre || currentEmployee.nombres || ''} ${currentEmployee.apellidos || ''}`.trim()
    : 'Empleado no seleccionado';

  const getParentescoBadge = (p) => {
    switch (p) {
      case 'Esposa':
      case 'Esposo':
        return 'bg-pink-100 text-pink-700 border-pink-200';
      case 'Hijo':
        return 'bg-blue-100 text-blue-700 border-blue-200';
      case 'Hija':
        return 'bg-purple-100 text-purple-700 border-purple-200';
      default:
        return 'bg-slate-100 text-slate-700 border-slate-200';
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Gestión de Familiares"
      subtitle="Registro de familiares del usuario"
      icon={Users}
      maxWidth="max-w-2xl"
    >
      <div className="space-y-6">
        {/* Selector de Empleado si no vino preseleccionado fijo */}
        {!employee && employees.length > 0 ? (
          <div>
            <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5 flex items-center space-x-1.5">
              <Briefcase className="w-3.5 h-3.5 text-emerald-600" />
              <span>Seleccionar Usuario Empleado *</span>
            </label>
            <select
              value={selectedEmpId}
              onChange={(e) => setSelectedEmpId(e.target.value)}
              className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm font-semibold text-slate-800 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white"
            >
              {employees.map((emp) => {
                const name = emp.nombre_completo || `${emp.nombre || emp.nombres || ''} ${emp.apellidos || ''}`.trim();
                return (
                  <option key={emp.id_usuario} value={emp.id_usuario}>
                    {name} (CI: {emp.ci_codigo || 'S/N'})
                  </option>
                );
              })}
            </select>
          </div>
        ) : (
          <div className="bg-emerald-50/70 border border-emerald-200/80 rounded-xl p-3.5 flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="p-2 bg-emerald-100 text-emerald-700 rounded-lg">
                <Briefcase className="w-4 h-4" />
              </div>
              <div>
                <p className="text-xs text-emerald-700 font-semibold uppercase">Empleado Vinculado</p>
                <p className="text-sm font-bold text-slate-900">{currentEmployeeName}</p>
              </div>
            </div>
            <span className="text-xs font-mono font-medium text-slate-600 bg-white px-2.5 py-1 rounded-md border border-emerald-200">
              CI: {currentEmployee?.ci_codigo || 'N/A'}
            </span>
          </div>
        )}

        {/* Sección: Lista de Familiares Registrados */}
        <div>
          <div className="flex items-center justify-between border-b border-slate-200 pb-2 mb-3">
            <h4 className="text-sm font-bold text-slate-800 flex items-center space-x-1.5">
              <Heart className="w-4 h-4 text-rose-500" />
              <span>Familiares Registrados ({familiares.length})</span>
            </h4>
          </div>

          {loadingList ? (
            <div className="py-6 text-center text-slate-500 text-xs">
              <div className="w-6 h-6 border-2 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto mb-2" />
              Cargando familiares...
            </div>
          ) : familiares.length === 0 ? (
            <div className="p-4 bg-slate-50 border border-dashed border-slate-200 rounded-xl text-center text-slate-500 text-xs">
              No hay familiares registrados aún para este empleado.
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
              {familiares.map((f) => {
                const p = f.persona || {};
                const familiarName = `${p.nombre || ''} ${p.apellidos || ''}`.trim() || 'Familiar sin nombre';
                const isDeleting = deletingId === f.id_persona;

                return (
                  <div
                    key={f.id_persona}
                    className="p-3 bg-white rounded-xl border border-slate-200 shadow-2xs flex items-center justify-between"
                  >
                    <div className="space-y-0.5">
                      <div className="flex items-center space-x-2">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-bold border ${getParentescoBadge(f.parentesco)}`}>
                          {f.parentesco}
                        </span>
                        <p className="text-xs font-bold text-slate-800">{familiarName}</p>
                      </div>
                      {p.telefono && (
                        <p className="text-[11px] text-slate-500 flex items-center space-x-1">
                          <Phone className="w-3 h-3 text-slate-400" />
                          <span>{p.telefono}</span>
                        </p>
                      )}
                    </div>
                    <button
                      type="button"
                      onClick={() => handleDelete(f)}
                      disabled={isDeleting}
                      className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
                      title="Desvincular familiar"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Sección: Formulario para Agregar Nuevo Familiar */}
        <form onSubmit={handleCreateSubmit} className="pt-2 border-t border-slate-200 space-y-4">
          <div className="flex items-center space-x-2">
            <UserPlus className="w-4 h-4 text-blue-600" />
            <h4 className="text-sm font-bold text-slate-800">Registrar Nuevo Familiar</h4>
          </div>

          {formError && (
            <div className="p-3 bg-rose-50 border border-rose-200 rounded-xl text-rose-700 text-xs flex items-start space-x-2">
              <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5 text-rose-500" />
              <span>{formError}</span>
            </div>
          )}

          {/* Parentesco Enum */}
          <div>
            <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
              Parentesco *
            </label>
            <div className="grid grid-cols-4 gap-2">
              {PARENTESCOS.map((rel) => (
                <button
                  key={rel}
                  type="button"
                  onClick={() => setFormData((prev) => ({ ...prev, parentesco: rel }))}
                  className={`py-2 rounded-xl text-xs font-bold transition border ${
                    formData.parentesco === rel
                      ? 'bg-blue-600 text-white border-blue-600 shadow-xs'
                      : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100'
                  }`}
                >
                  {rel}
                </button>
              ))}
            </div>
          </div>

          {/* Datos Personales del Familiar */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                Nombre del Familiar *
              </label>
              <div className="relative">
                <User className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  name="nombre"
                  value={formData.nombre}
                  onChange={handleInputChange}
                  placeholder="Ej. María"
                  required
                  className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                Apellidos *
              </label>
              <input
                type="text"
                name="apellidos"
                value={formData.apellidos}
                onChange={handleInputChange}
                placeholder="Ej. Gómez"
                required
                className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
              Teléfono (Opcional)
            </label>
            <div className="relative">
              <Phone className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="tel"
                name="telefono"
                value={formData.telefono}
                onChange={handleInputChange}
                placeholder="Ej. 78945612"
                className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white"
              />
            </div>
          </div>

          <div className="flex items-center justify-end space-x-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-800 hover:bg-slate-100 rounded-xl transition"
            >
              Cerrar
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="flex items-center space-x-1.5 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold rounded-xl shadow-md transition disabled:opacity-50"
            >
              {submitting ? (
                <div className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
              ) : (
                <>
                  <Check className="w-3.5 h-3.5" />
                  <span>Vincular Familiar</span>
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </Modal>
  );
}
