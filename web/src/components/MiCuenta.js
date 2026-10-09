import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { updateUserProfile, updatePassword } from '../lib/supabaseClient';
import { 
  User, 
  Mail, 
  Lock, 
  Bell, 
  Phone, 
  CreditCard, 
  CheckCircle2, 
  AlertCircle, 
  Shield, 
  Save,
  KeyRound,
  Eye,
  EyeOff
} from 'lucide-react';

export default function MiCuenta() {
  const { user, profile, role, refreshProfile, setProfile } = useAuth();

  const [nombres, setNombres] = useState('');
  const [apellidos, setApellidos] = useState('');
  const [telefono, setTelefono] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [notificaciones, setNotificaciones] = useState('on');

  const [savingProfile, setSavingProfile] = useState(false);
  const [savingPassword, setSavingPassword] = useState(false);
  const [successMessage, setSuccessMessage] = useState(null);
  const [errorMessage, setErrorMessage] = useState(null);

  useEffect(() => {
    if (profile) {
      setNombres(profile.nombres || '');
      setApellidos(profile.apellidos || '');
      setTelefono(profile.telefono || '');
    }
  }, [profile]);

  const showToast = (msg) => {
    setSuccessMessage(msg);
    setErrorMessage(null);
    setTimeout(() => setSuccessMessage(null), 4000);
  };

  const handleProfileSubmit = async (e) => {
    e.preventDefault();
    setErrorMessage(null);

    if (!nombres.trim()) {
      setErrorMessage('El nombre no puede estar vacío.');
      return;
    }

    try {
      setSavingProfile(true);
      if (user?.id) {
        await updateUserProfile(user.id, {
          nombres: nombres.trim(),
          apellidos: apellidos.trim(),
          telefono: telefono.trim(),
        });
        setProfile((prev) => ({
          ...prev,
          nombres: nombres.trim(),
          apellidos: apellidos.trim(),
          telefono: telefono.trim(),
        }));
        await refreshProfile();
        showToast('Datos personales actualizados correctamente.');
      }
    } catch (err) {
      console.error('Error updating profile:', err);
      setErrorMessage(err.message || 'Error al actualizar el perfil.');
    } finally {
      setSavingProfile(false);
    }
  };

  const handlePasswordSubmit = async (e) => {
    e.preventDefault();
    setErrorMessage(null);

    if (!newPassword || newPassword.length < 6) {
      setErrorMessage('La nueva contraseña debe tener al menos 6 caracteres.');
      return;
    }

    if (newPassword !== confirmPassword) {
      setErrorMessage('Las contraseñas ingresadas no coinciden.');
      return;
    }

    try {
      setSavingPassword(true);
      await updatePassword(newPassword);
      setNewPassword('');
      setConfirmPassword('');
      showToast('Contraseña actualizada con éxito.');
    } catch (err) {
      console.error('Error updating password:', err);
      setErrorMessage(err.message || 'Error al actualizar la contraseña.');
    } finally {
      setSavingPassword(false);
    }
  };

  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      {/* Alert Messages */}
      {successMessage && (
        <div className="p-4 bg-emerald-50 border border-emerald-200 rounded-2xl flex items-center space-x-3 text-emerald-800 text-sm animate-fade-in shadow-sm">
          <CheckCircle2 className="w-5 h-5 flex-shrink-0 text-emerald-600" />
          <span className="font-semibold">{successMessage}</span>
        </div>
      )}

      {errorMessage && (
        <div className="p-4 bg-rose-50 border border-rose-200 rounded-2xl flex items-center space-x-3 text-rose-800 text-sm animate-fade-in shadow-sm">
          <AlertCircle className="w-5 h-5 flex-shrink-0 text-rose-600" />
          <span className="font-semibold">{errorMessage}</span>
        </div>
      )}

      {/* Profile Card matching cuenta.html */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200/80 overflow-hidden">
        {/* Header */}
        <div className="bg-gradient-to-r from-blue-700 to-indigo-700 text-white p-6 text-center relative">
          <div className="w-16 h-16 rounded-full bg-white/15 text-white font-bold text-2xl flex items-center justify-center mx-auto mb-2 border-2 border-white/30 shadow-inner">
            {(profile?.nombres?.charAt(0) || user?.email?.charAt(0) || 'U').toUpperCase()}
          </div>
          <h2 className="text-xl font-bold">Mi Cuenta</h2>
          <p className="text-blue-100 text-xs mt-0.5 font-medium">
            Administra tus datos personales y credenciales de acceso
          </p>
          <div className="mt-2 inline-flex items-center space-x-1 bg-white/20 px-3 py-0.5 rounded-full text-xs font-semibold text-white">
            <Shield className="w-3.5 h-3.5" />
            <span>Rol: {role}</span>
          </div>
        </div>

        {/* Body Forms */}
        <div className="p-6 sm:p-8 space-y-8 bg-slate-50/50">
          {/* Personal Info Form */}
          <form onSubmit={handleProfileSubmit} className="space-y-4">
            <h3 className="text-base font-bold text-slate-800 border-b border-slate-200 pb-2 flex items-center space-x-2">
              <User className="w-4 h-4 text-blue-600" />
              <span>Información Personal</span>
            </h3>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Nombres
                </label>
                <div className="relative">
                  <User className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="text"
                    value={nombres}
                    onChange={(e) => setNombres(e.target.value)}
                    placeholder="Ingresa tu nombre"
                    required
                    className="w-full pl-10 pr-3 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 transition shadow-xs"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Apellidos
                </label>
                <input
                  type="text"
                  value={apellidos}
                  onChange={(e) => setApellidos(e.target.value)}
                  placeholder="Ingresa tus apellidos"
                  className="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 transition shadow-xs"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Cédula / C.I.
                </label>
                <div className="relative">
                  <CreditCard className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="text"
                    value={profile?.ci_codigo || ''}
                    disabled
                    className="w-full pl-10 pr-3 py-2.5 bg-slate-100 border border-slate-200 rounded-xl text-sm text-slate-500 font-mono cursor-not-allowed"
                    title="El C.I. es un identificador institucional único asignado por el Administrador"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Teléfono
                </label>
                <div className="relative">
                  <Phone className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="tel"
                    value={telefono}
                    onChange={(e) => setTelefono(e.target.value)}
                    placeholder="71234567"
                    className="w-full pl-10 pr-3 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 transition shadow-xs"
                  />
                </div>
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                Correo Electrónico (Cuenta)
              </label>
              <div className="relative">
                <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="email"
                  value={user?.email || ''}
                  disabled
                  className="w-full pl-10 pr-3 py-2.5 bg-slate-100 border border-slate-200 rounded-xl text-sm text-slate-500 font-mono cursor-not-allowed"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                Notificaciones
              </label>
              <div className="relative">
                <Bell className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                <select
                  value={notificaciones}
                  onChange={(e) => setNotificaciones(e.target.value)}
                  className="w-full pl-10 pr-3 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 transition shadow-xs"
                >
                  <option value="on">Activadas (Recibir avisos de menús y reportes)</option>
                  <option value="off">Desactivadas</option>
                </select>
              </div>
            </div>

            <div className="pt-2 text-right">
              <button
                type="submit"
                disabled={savingProfile}
                className="inline-flex items-center space-x-2 px-6 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold rounded-xl shadow-md transition disabled:opacity-50"
              >
                {savingProfile ? (
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                ) : (
                  <>
                    <Save className="w-4 h-4" />
                    <span>Guardar Cambios</span>
                  </>
                )}
              </button>
            </div>
          </form>

          {/* Change Password Section (HU2) */}
          <form onSubmit={handlePasswordSubmit} className="space-y-4 pt-4 border-t border-slate-200">
            <h3 className="text-base font-bold text-slate-800 border-b border-slate-200 pb-2 flex items-center space-x-2">
              <KeyRound className="w-4 h-4 text-indigo-600" />
              <span>Cambiar Contraseña</span>
            </h3>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Nueva Contraseña
                </label>
                <div className="relative">
                  <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    placeholder="Mínimo 6 caracteres"
                    minLength={6}
                    required
                    className="w-full pl-10 pr-10 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 transition shadow-xs"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Confirmar Contraseña
                </label>
                <div className="relative">
                  <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    placeholder="Repite la contraseña"
                    minLength={6}
                    required
                    className="w-full pl-10 pr-3 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 transition shadow-xs"
                  />
                </div>
              </div>
            </div>

            <div className="pt-2 text-right">
              <button
                type="submit"
                disabled={savingPassword || !newPassword}
                className="inline-flex items-center space-x-2 px-6 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-xl shadow-md transition disabled:opacity-50"
              >
                {savingPassword ? (
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                ) : (
                  <>
                    <KeyRound className="w-4 h-4" />
                    <span>Actualizar Contraseña</span>
                  </>
                )}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
