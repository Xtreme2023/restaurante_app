import React, { useState } from 'react';
import Modal from '../Modal';
import { createAdminUser } from '../../lib/supabaseClient';
import { 
  UserPlus, 
  User, 
  CreditCard, 
  Phone, 
  Mail, 
  Lock, 
  AlertCircle, 
  Check 
} from 'lucide-react';

/**
 * Modal para registrar nuevos usuarios e integrantes en el sistema
 * Reutiliza el componente Modal general
 */
export default function UsuarioCreateModal({
  isOpen,
  onClose,
  onUserCreated,
  showToast,
}) {
  const initialFormState = {
    nombre: '',
    apellidos: '',
    ci_codigo: '',
    telefono: '',
    email: '',
    password: '',
    rol: 'Empleado',
  };

  const [formData, setFormData] = useState(initialFormState);
  const [formSubmitting, setFormSubmitting] = useState(false);
  const [formError, setFormError] = useState(null);

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setFormError(null);

    // Validaciones
    if (!formData.nombre.trim()) {
      setFormError('El nombre es obligatorio.');
      return;
    }
    if (!formData.apellidos.trim()) {
      setFormError('Los apellidos son obligatorios.');
      return;
    }
    if (!formData.ci_codigo.trim()) {
      setFormError('El número de CI es obligatorio.');
      return;
    }
    if (!formData.telefono.trim()) {
      setFormError('El teléfono es obligatorio.');
      return;
    }
    if (!formData.email.trim()) {
      setFormError('El correo electrónico es obligatorio.');
      return;
    }
    if (!formData.password || formData.password.length < 6) {
      setFormError('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (!formData.rol) {
      setFormError('Debe seleccionar un rol para el usuario.');
      return;
    }

    try {
      setFormSubmitting(true);
      await createAdminUser({
        ...formData,
        nombres: formData.nombre.trim(),
        nombre: formData.nombre.trim(),
        apellidos: formData.apellidos.trim(),
        ci_codigo: formData.ci_codigo.trim(),
        telefono: formData.telefono.trim(),
      });

      showToast?.(`Usuario ${formData.nombre} ${formData.apellidos} registrado exitosamente.`);
      setFormData(initialFormState);
      onClose();
      await onUserCreated?.();
    } catch (err) {
      console.error('Error creating user:', err);
      setFormError(err.message || 'Error al crear usuario en Supabase.');
    } finally {
      setFormSubmitting(false);
    }
  };

  const handleModalClose = () => {
    setFormError(null);
    onClose();
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={handleModalClose}
      title="Agregar Nuevo Usuario"
      subtitle="Registro de usuarios, por favor complete los datos."
      icon={UserPlus}
      maxWidth="max-w-lg"
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        {formError && (
          <div className="p-3 bg-rose-50 border border-rose-200 rounded-xl text-rose-700 text-xs flex items-start space-x-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5 text-rose-500" />
            <div>
              <span className="font-bold block">No se pudo crear el usuario:</span>
              <span>{formError}</span>
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {/* Nombre */}
          <div>
            <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
              Nombre(s) *
            </label>
            <div className="relative">
              <User className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                name="nombre"
                value={formData.nombre}
                onChange={handleInputChange}
                placeholder="Ej. Juan Carlos"
                required
                className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white"
              />
            </div>
          </div>

          {/* Apellidos */}
          <div>
            <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
              Apellidos *
            </label>
            <input
              type="text"
              name="apellidos"
              value={formData.apellidos}
              onChange={handleInputChange}
              placeholder="Ej. Guzman"
              required
              className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white"
            />
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {/* CI Código */}
          <div>
            <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
              C.I. / Documento *
            </label>
            <div className="relative">
              <CreditCard className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                name="ci_codigo"
                value={formData.ci_codigo}
                onChange={handleInputChange}
                placeholder="Ej. 78945612"
                required
                className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white"
              />
            </div>
          </div>

          {/* Teléfono */}
          <div>
            <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
              Teléfono *
            </label>
            <div className="relative">
              <Phone className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="tel"
                name="telefono"
                value={formData.telefono}
                onChange={handleInputChange}
                placeholder="Ej. 71234567"
                required
                className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white"
              />
            </div>
          </div>
        </div>

        {/* Correo Electrónico */}
        <div>
          <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
            Correo Electrónico *
          </label>
          <div className="relative">
            <Mail className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="email"
              name="email"
              value={formData.email}
              onChange={handleInputChange}
              placeholder="usuario@institucion.bo"
              required
              className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white"
            />
          </div>
        </div>

        {/* Contraseña */}
        <div>
          <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
            Contraseña de Acceso *
          </label>
          <div className="relative">
            <Lock className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="password"
              name="password"
              value={formData.password}
              onChange={handleInputChange}
              placeholder="Mínimo 6 caracteres"
              required
              minLength={6}
              className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white"
            />
          </div>
        </div>

        {/* Rol ENUM */}
        <div>
          <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
            Rol Asignado *
          </label>
          <select
            name="rol"
            value={formData.rol}
            onChange={handleInputChange}
            required
            className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm font-medium focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white"
          >
            <option value="Empleado">Empleado (Personal de atención / comedor)</option>
            <option value="Institucion">Institución (Representante institucional)</option>
            <option value="Administrador">Administrador (Gestión total del sistema)</option>
          </select>
        </div>

        {/* Action Buttons */}
        <div className="pt-3 flex items-center justify-end space-x-3 border-t border-slate-100">
          <button
            type="button"
            onClick={handleModalClose}
            className="px-4 py-2 text-sm font-medium text-slate-600 hover:text-slate-800 hover:bg-slate-100 rounded-xl transition"
          >
            Cancelar
          </button>
          <button
            type="submit"
            disabled={formSubmitting}
            className="flex items-center space-x-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold rounded-xl shadow-md hover:shadow-emerald-600/30 transition-all disabled:opacity-50"
          >
            {formSubmitting ? (
              <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
            ) : (
              <>
                <Check className="w-4 h-4" />
                <span>Guardar Usuario</span>
              </>
            )}
          </button>
        </div>
      </form>
    </Modal>
  );
}
