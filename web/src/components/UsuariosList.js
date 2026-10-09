import React, { useState, useEffect, useMemo } from 'react';
import { 
  fetchUsuarios, 
  createAdminUser, 
  toggleUserStatus, 
  deleteUserPermanently 
} from '../lib/supabaseClient';
import { 
  UserPlus, 
  Search, 
  Users, 
  Shield, 
  Briefcase, 
  Building2, 
  CheckCircle2, 
  XCircle, 
  Eye, 
  UserX, 
  UserCheck, 
  Trash2, 
  X, 
  AlertCircle, 
  Check, 
  RefreshCw, 
  Lock, 
  Mail, 
  Phone, 
  CreditCard, 
  User,
  HelpCircle,
  Clock
} from 'lucide-react';

export default function UsuariosList() {
  const [usuarios, setUsuarios] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [roleFilter, setRoleFilter] = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');

  // Modal states
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [showDeleteModal, setShowDeleteModal] = useState(null);

  // Form State for creating user
  const [formData, setFormData] = useState({
    nombres: '',
    apellidos: '',
    ci_codigo: '',
    telefono: '',
    email: '',
    password: '',
    rol: 'Empleado', // 'Administrador', 'Empleado', 'Institucion'
  });
  const [formSubmitting, setFormSubmitting] = useState(false);
  const [formError, setFormError] = useState(null);
  const [successToast, setSuccessToast] = useState(null);

  // Action loading state for individual rows
  const [actionLoadingId, setActionLoadingId] = useState(null);

  const loadUsuarios = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await fetchUsuarios();
      setUsuarios(data);
    } catch (err) {
      console.error('Error fetching users:', err);
      setError('No se pudieron cargar los usuarios. Por favor verifica la conexión con Supabase.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadUsuarios();
  }, []);

  const showToast = (message) => {
    setSuccessToast(message);
    setTimeout(() => {
      setSuccessToast(null);
    }, 4000);
  };

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

    // Validation
    if (!formData.nombres.trim()) {
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
      await createAdminUser(formData);
      showToast(`Usuario ${formData.nombres} ${formData.apellidos} registrado exitosamente.`);
      setShowCreateModal(false);
      // Reset form
      setFormData({
        nombres: '',
        apellidos: '',
        ci_codigo: '',
        telefono: '',
        email: '',
        password: '',
        rol: 'Empleado',
      });
      // Refresh list
      await loadUsuarios();
    } catch (err) {
      console.error('Error creating user:', err);
      setFormError(err.message || 'Error al crear usuario en Supabase.');
    } finally {
      setFormSubmitting(false);
    }
  };

  const handleToggleStatus = async (user) => {
    const nextState = !user.activo;
    try {
      setActionLoadingId(user.id_usuario);
      await toggleUserStatus(user.id_usuario, nextState);
      showToast(`Acceso ${nextState ? 'activado' : 'anulado'} para ${user.nombres} ${user.apellidos}.`);
      setUsuarios((prev) =>
        prev.map((u) => (u.id_usuario === user.id_usuario ? { ...u, activo: nextState } : u))
      );
    } catch (err) {
      console.error('Error toggling user status:', err);
      alert('Error al modificar el estado del usuario.');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleDeleteUser = async (userId) => {
    try {
      setActionLoadingId(userId);
      await deleteUserPermanently(userId);
      showToast('Usuario eliminado permanentemente.');
      setShowDeleteModal(null);
      setUsuarios((prev) => prev.filter((u) => u.id_usuario !== userId));
    } catch (err) {
      console.error('Error deleting user:', err);
      alert('Error al eliminar usuario.');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Filtered list based on search and filters
  const filteredUsuarios = useMemo(() => {
    return usuarios.filter((u) => {
      const matchesSearch =
        u.nombres?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        u.apellidos?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        u.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        u.ci_codigo?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        u.telefono?.includes(searchTerm);

      const matchesRole = roleFilter === 'ALL' || u.rol === roleFilter;
      const matchesStatus =
        statusFilter === 'ALL' ||
        (statusFilter === 'ACTIVE' && u.activo !== false) ||
        (statusFilter === 'INACTIVE' && u.activo === false);

      return matchesSearch && matchesRole && matchesStatus;
    });
  }, [usuarios, searchTerm, roleFilter, statusFilter]);

  // Metric counts
  const stats = useMemo(() => {
    const total = usuarios.length;
    const adminCount = usuarios.filter((u) => u.rol === 'Administrador').length;
    const empleadoCount = usuarios.filter((u) => u.rol === 'Empleado').length;
    const institucionCount = usuarios.filter((u) => u.rol === 'Institucion').length;
    const activos = usuarios.filter((u) => u.activo !== false).length;
    return { total, adminCount, empleadoCount, institucionCount, activos };
  }, [usuarios]);

  const getRoleBadge = (rol) => {
    switch (rol) {
      case 'Administrador':
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-purple-100 text-purple-800 border border-purple-200">
            <Shield className="w-3 h-3 mr-1 text-purple-600" /> Administrador
          </span>
        );
      case 'Empleado':
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 border border-emerald-200">
            <Briefcase className="w-3 h-3 mr-1 text-emerald-600" /> Empleado
          </span>
        );
      case 'Institucion':
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-amber-100 text-amber-800 border border-amber-200">
            <Building2 className="w-3 h-3 mr-1 text-amber-600" /> Institución
          </span>
        );
      default:
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-slate-100 text-slate-800">
            {rol || 'Sin Rol'}
          </span>
        );
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      {/* Success Notification Toast */}
      {successToast && (
        <div className="fixed bottom-5 right-5 z-50 bg-emerald-600 text-white px-5 py-3.5 rounded-xl shadow-2xl flex items-center space-x-3 animate-fade-in border border-emerald-400">
          <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
          <span className="text-sm font-medium">{successToast}</span>
        </div>
      )}

      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 bg-white p-6 rounded-2xl shadow-sm border border-slate-200/80">
        <div>
          <div className="flex items-center space-x-2">
            <div className="p-2 bg-blue-50 rounded-xl text-blue-600">
              <Users className="w-6 h-6" />
            </div>
            <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Gestión de Usuarios</h1>
          </div>
          <p className="text-slate-500 text-sm mt-1">
            Administración de cuentas, roles y accesos institucionales al sistema de restaurante.
          </p>
        </div>

        <div className="flex items-center space-x-3">
          <button
            onClick={loadUsuarios}
            disabled={loading}
            className="p-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-600 transition shadow-xs"
            title="Refrescar datos"
          >
            <RefreshCw className={`w-5 h-5 ${loading ? 'animate-spin text-blue-600' : ''}`} />
          </button>
          
          <button
            onClick={() => setShowCreateModal(true)}
            className="flex items-center space-x-2 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold px-4 py-2.5 rounded-xl shadow-md hover:shadow-emerald-600/20 transform active:scale-95 transition-all duration-200"
          >
            <UserPlus className="w-5 h-5" />
            <span>Agregar Nuevo Usuario</span>
          </button>
        </div>
      </div>

      {/* Quick Statistics Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3 sm:gap-4">
        <div className="bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs flex items-center space-x-3">
          <div className="p-2.5 bg-blue-50 text-blue-600 rounded-lg">
            <Users className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs font-medium text-slate-500">Total Usuarios</p>
            <p className="text-xl font-bold text-slate-900">{stats.total}</p>
          </div>
        </div>

        <div className="bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs flex items-center space-x-3">
          <div className="p-2.5 bg-purple-50 text-purple-600 rounded-lg">
            <Shield className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs font-medium text-slate-500">Administradores</p>
            <p className="text-xl font-bold text-purple-700">{stats.adminCount}</p>
          </div>
        </div>

        <div className="bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs flex items-center space-x-3">
          <div className="p-2.5 bg-emerald-50 text-emerald-600 rounded-lg">
            <Briefcase className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs font-medium text-slate-500">Empleados</p>
            <p className="text-xl font-bold text-emerald-700">{stats.empleadoCount}</p>
          </div>
        </div>

        <div className="bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs flex items-center space-x-3">
          <div className="p-2.5 bg-amber-50 text-amber-600 rounded-lg">
            <Building2 className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs font-medium text-slate-500">Instituciones</p>
            <p className="text-xl font-bold text-amber-700">{stats.institucionCount}</p>
          </div>
        </div>

        <div className="bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs flex items-center space-x-3 col-span-2 sm:col-span-1">
          <div className="p-2.5 bg-teal-50 text-teal-600 rounded-lg">
            <CheckCircle2 className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs font-medium text-slate-500">Cuentas Activas</p>
            <p className="text-xl font-bold text-teal-700">{stats.activos}</p>
          </div>
        </div>
      </div>

      {/* Search & Filters */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-sm flex flex-col md:flex-row md:items-center md:justify-between gap-3">
        {/* Search bar */}
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Buscar por nombre, CI, teléfono o correo..."
            className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
          />
          {searchTerm && (
            <button
              onClick={() => setSearchTerm('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 text-xs"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Filter Pills */}
        <div className="flex flex-wrap items-center gap-2">
          <div className="flex items-center bg-slate-100 p-1 rounded-xl text-xs font-medium">
            {['ALL', 'Administrador', 'Empleado', 'Institucion'].map((r) => (
              <button
                key={r}
                onClick={() => setRoleFilter(r)}
                className={`px-3 py-1.5 rounded-lg transition ${
                  roleFilter === r
                    ? 'bg-white text-blue-700 font-semibold shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                {r === 'ALL' ? 'Todos los roles' : r}
              </button>
            ))}
          </div>

          <div className="flex items-center bg-slate-100 p-1 rounded-xl text-xs font-medium">
            {[
              { id: 'ALL', label: 'Todos' },
              { id: 'ACTIVE', label: 'Activos' },
              { id: 'INACTIVE', label: 'Inactivos' },
            ].map((s) => (
              <button
                key={s.id}
                onClick={() => setStatusFilter(s.id)}
                className={`px-3 py-1.5 rounded-lg transition ${
                  statusFilter === s.id
                    ? 'bg-white text-blue-700 font-semibold shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                {s.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Main Table Card */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200/80 overflow-hidden">
        {/* Table Header Section matching HTML */}
        <div className="bg-gradient-to-r from-blue-700 to-indigo-700 text-white px-6 py-4 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <Users className="w-5 h-5 text-blue-200" />
            <h3 className="font-bold text-lg tracking-tight">Listado de Usuarios e Integrantes</h3>
          </div>
          <span className="text-xs font-semibold bg-white/15 px-3 py-1 rounded-full border border-white/20">
            {filteredUsuarios.length} de {usuarios.length} registrados
          </span>
        </div>

        {/* Table Content */}
        {loading ? (
          <div className="py-16 text-center">
            <div className="w-10 h-10 border-3 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
            <p className="text-slate-500 text-sm font-medium">Cargando usuarios desde Supabase...</p>
          </div>
        ) : error ? (
          <div className="p-8 text-center bg-rose-50/50">
            <AlertCircle className="w-10 h-10 text-rose-500 mx-auto mb-2" />
            <p className="text-rose-700 font-semibold">{error}</p>
            <button
              onClick={loadUsuarios}
              className="mt-3 inline-flex items-center space-x-2 px-4 py-2 bg-rose-600 text-white rounded-xl text-sm font-medium hover:bg-rose-700 transition"
            >
              <RefreshCw className="w-4 h-4" />
              <span>Reintentar</span>
            </button>
          </div>
        ) : filteredUsuarios.length === 0 ? (
          <div className="py-16 text-center px-4">
            <Users className="w-12 h-12 text-slate-300 mx-auto mb-3" />
            <h4 className="text-base font-semibold text-slate-700">No se encontraron usuarios</h4>
            <p className="text-slate-400 text-sm mt-1 max-w-sm mx-auto">
              No hay coincidencias con los criterios de búsqueda o filtros seleccionados.
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-blue-50/70 border-b border-blue-100 text-blue-900 text-xs uppercase font-bold tracking-wider">
                  <th className="py-3.5 px-4 sm:px-6">Usuario / Nombre</th>
                  <th className="py-3.5 px-4">CI / Código</th>
                  <th className="py-3.5 px-4">Teléfono</th>
                  <th className="py-3.5 px-4">Correo Electrónico</th>
                  <th className="py-3.5 px-4">Rol</th>
                  <th className="py-3.5 px-4">Estado</th>
                  <th className="py-3.5 px-4 sm:px-6 text-right">Acciones</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-sm text-slate-700">
                {filteredUsuarios.map((u) => {
                  const isUserActive = u.activo !== false;
                  const fullName = `${u.nombres || ''} ${u.apellidos || ''}`.trim() || 'Sin Nombre';
                  const initials = `${u.nombres?.charAt(0) || ''}${u.apellidos?.charAt(0) || ''}`.toUpperCase() || 'U';
                  const isLoadingAction = actionLoadingId === u.id_usuario;

                  return (
                    <tr 
                      key={u.id_usuario}
                      className="hover:bg-slate-50/80 transition-colors duration-150 group"
                    >
                      {/* Name with Avatar */}
                      <td className="py-3.5 px-4 sm:px-6">
                        <div className="flex items-center space-x-3">
                          <div className={`w-9 h-9 rounded-full flex items-center justify-center font-bold text-xs shadow-xs ${
                            u.rol === 'Administrador' 
                              ? 'bg-purple-100 text-purple-700 border border-purple-200' 
                              : u.rol === 'Institucion'
                              ? 'bg-amber-100 text-amber-700 border border-amber-200'
                              : 'bg-blue-100 text-blue-700 border border-blue-200'
                          }`}>
                            {initials}
                          </div>
                          <div>
                            <span className="font-semibold text-slate-900 block">{fullName}</span>
                            <span className="text-xs text-slate-400 font-mono">ID: {u.id_usuario?.substring(0, 8)}...</span>
                          </div>
                        </div>
                      </td>

                      {/* CI */}
                      <td className="py-3.5 px-4">
                        <span className="inline-flex items-center font-mono text-xs bg-slate-100 px-2 py-1 rounded-md text-slate-700 font-medium">
                          {u.ci_codigo || 'N/A'}
                        </span>
                      </td>

                      {/* Teléfono */}
                      <td className="py-3.5 px-4">
                        <span className="text-slate-600 font-medium">{u.telefono || '—'}</span>
                      </td>

                      {/* Correo */}
                      <td className="py-3.5 px-4">
                        <span className="text-slate-600 font-mono text-xs">{u.email}</span>
                      </td>

                      {/* Rol */}
                      <td className="py-3.5 px-4">
                        {getRoleBadge(u.rol)}
                      </td>

                      {/* Estado */}
                      <td className="py-3.5 px-4">
                        {isUserActive ? (
                          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 mr-1.5 animate-pulse" /> Activo
                          </span>
                        ) : (
                          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold bg-rose-50 text-rose-700 border border-rose-200">
                            <span className="w-1.5 h-1.5 rounded-full bg-rose-500 mr-1.5" /> Inactivo
                          </span>
                        )}
                      </td>

                      {/* Acciones */}
                      <td className="py-3.5 px-4 sm:px-6 text-right">
                        <div className="flex items-center justify-end space-x-1.5">
                          {/* Detalles */}
                          <button
                            onClick={() => setSelectedUser(u)}
                            className="px-2.5 py-1.5 bg-blue-50 hover:bg-blue-100 text-blue-700 rounded-lg text-xs font-semibold transition flex items-center space-x-1"
                            title="Ver detalles"
                          >
                            <Eye className="w-3.5 h-3.5" />
                            <span className="hidden sm:inline">Detalles</span>
                          </button>

                          {/* Anular acceso / Activar (HU4) */}
                          <button
                            onClick={() => handleToggleStatus(u)}
                            disabled={isLoadingAction}
                            className={`px-2.5 py-1.5 rounded-lg text-xs font-semibold transition flex items-center space-x-1 ${
                              isUserActive
                                ? 'bg-rose-50 hover:bg-rose-100 text-rose-700'
                                : 'bg-emerald-50 hover:bg-emerald-100 text-emerald-700'
                            }`}
                            title={isUserActive ? 'Anular acceso' : 'Reactivar acceso'}
                          >
                            {isUserActive ? (
                              <>
                                <UserX className="w-3.5 h-3.5" />
                                <span className="hidden md:inline">Anular acceso</span>
                              </>
                            ) : (
                              <>
                                <UserCheck className="w-3.5 h-3.5" />
                                <span className="hidden md:inline">Activar</span>
                              </>
                            )}
                          </button>

                          {/* Eliminar permanente */}
                          <button
                            onClick={() => setShowDeleteModal(u)}
                            className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
                            title="Eliminar usuario"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* MODAL: Agregar Nuevo Usuario (HU3) */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 overflow-y-auto bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="relative w-full max-w-lg bg-white rounded-2xl shadow-2xl overflow-hidden animate-fade-in-up border border-slate-100">
            {/* Modal Header */}
            <div className="bg-gradient-to-r from-blue-700 to-indigo-700 text-white p-5 flex items-center justify-between">
              <div className="flex items-center space-x-2.5">
                <UserPlus className="w-6 h-6 text-blue-200" />
                <h3 className="text-lg font-bold">Agregar Nuevo Usuario</h3>
              </div>
              <button
                onClick={() => setShowCreateModal(false)}
                className="text-white/80 hover:text-white p-1 rounded-lg hover:bg-white/10 transition"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Form */}
            <form onSubmit={handleCreateSubmit} className="p-6 space-y-4">
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
                {/* Nombres */}
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                    Nombres *
                  </label>
                  <div className="relative">
                    <User className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                    <input
                      type="text"
                      name="nombres"
                      value={formData.nombres}
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
                <p className="text-[11px] text-slate-500 mt-1">
                  Los administradores tienen acceso a la gestión de usuarios, menú y reportes.
                </p>
              </div>

              {/* Buttons */}
              <div className="pt-3 flex items-center justify-end space-x-3">
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
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
          </div>
        </div>
      )}

      {/* MODAL: Detalles de Usuario */}
      {selectedUser && (
        <div className="fixed inset-0 z-50 overflow-y-auto bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="relative w-full max-w-md bg-white rounded-2xl shadow-2xl overflow-hidden animate-fade-in-up border border-slate-100">
            <div className="bg-gradient-to-r from-blue-700 to-indigo-700 text-white p-6 text-center relative">
              <button
                onClick={() => setSelectedUser(null)}
                className="absolute right-4 top-4 text-white/80 hover:text-white p-1 rounded-lg hover:bg-white/10 transition"
              >
                <X className="w-5 h-5" />
              </button>
              <div className="w-16 h-16 rounded-full bg-white/20 text-white font-bold text-2xl flex items-center justify-center mx-auto mb-2 border-2 border-white/40 shadow-inner">
                {selectedUser.nombres?.charAt(0)}{selectedUser.apellidos?.charAt(0)}
              </div>
              <h3 className="text-xl font-bold">{selectedUser.nombres} {selectedUser.apellidos}</h3>
              <div className="mt-2 flex justify-center">
                {getRoleBadge(selectedUser.rol)}
              </div>
            </div>

            <div className="p-6 space-y-3.5 text-sm bg-slate-50/50">
              <div className="flex justify-between items-center py-2 border-b border-slate-200">
                <span className="text-slate-500 font-medium">Estado de cuenta</span>
                <span>
                  {selectedUser.activo !== false ? (
                    <span className="text-emerald-700 font-bold bg-emerald-50 px-2.5 py-0.5 rounded-full border border-emerald-200">Activo</span>
                  ) : (
                    <span className="text-rose-700 font-bold bg-rose-50 px-2.5 py-0.5 rounded-full border border-rose-200">Inactivo / Bloqueado</span>
                  )}
                </span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-slate-200">
                <span className="text-slate-500 font-medium">Cédula / C.I.</span>
                <span className="font-mono font-semibold text-slate-800">{selectedUser.ci_codigo || 'N/A'}</span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-slate-200">
                <span className="text-slate-500 font-medium">Teléfono</span>
                <span className="font-semibold text-slate-800">{selectedUser.telefono || 'N/A'}</span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-slate-200">
                <span className="text-slate-500 font-medium">Correo electrónico</span>
                <span className="font-mono text-xs font-semibold text-slate-800">{selectedUser.email}</span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-slate-200">
                <span className="text-slate-500 font-medium">Fecha de registro</span>
                <span className="text-xs text-slate-600 flex items-center">
                  <Clock className="w-3.5 h-3.5 mr-1 text-slate-400" />
                  {selectedUser.created_at ? new Date(selectedUser.created_at).toLocaleString() : 'N/A'}
                </span>
              </div>

              <div className="pt-3">
                <button
                  onClick={() => setSelectedUser(null)}
                  className="w-full py-2.5 bg-slate-200 hover:bg-slate-300 text-slate-800 font-semibold rounded-xl text-sm transition"
                >
                  Cerrar
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: Confirmar Eliminación */}
      {showDeleteModal && (
        <div className="fixed inset-0 z-50 overflow-y-auto bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="relative w-full max-w-sm bg-white rounded-2xl shadow-2xl p-6 text-center animate-fade-in-up border border-slate-100">
            <div className="w-12 h-12 rounded-full bg-rose-100 text-rose-600 flex items-center justify-center mx-auto mb-3">
              <Trash2 className="w-6 h-6" />
            </div>
            <h3 className="text-lg font-bold text-slate-900">¿Eliminar usuario?</h3>
            <p className="text-slate-500 text-xs mt-2">
              Esta acción borrará permanentemente a <strong>{showDeleteModal.nombres} {showDeleteModal.apellidos}</strong> de la base de datos y de la autenticación de Supabase.
            </p>
            <div className="mt-5 flex items-center justify-center space-x-3">
              <button
                onClick={() => setShowDeleteModal(null)}
                className="px-4 py-2 bg-slate-100 text-slate-700 text-sm font-medium rounded-xl hover:bg-slate-200 transition"
              >
                Cancelar
              </button>
              <button
                onClick={() => handleDeleteUser(showDeleteModal.id_usuario)}
                className="px-4 py-2 bg-rose-600 text-white text-sm font-semibold rounded-xl hover:bg-rose-700 transition"
              >
                Sí, Eliminar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
