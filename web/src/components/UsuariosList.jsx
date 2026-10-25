import React, { useState, useEffect, useMemo } from 'react';
import { 
  fetchUsuarios, 
  toggleUserStatus, 
  deleteUserPermanently 
} from '../lib/supabaseClient';
import { Users, UserPlus, RefreshCw, CheckCircle2 } from 'lucide-react';

import UsuariosStats from './usuarios/UsuariosStats';
import UsuariosFilter from './usuarios/UsuariosFilter';
import UsuariosTable from './usuarios/UsuariosTable';
import UsuarioCreateModal from './usuarios/UsuarioCreateModal';
import UsuarioDetailsModal from './usuarios/UsuarioDetailsModal';
import UsuarioDeleteModal from './usuarios/UsuarioDeleteModal';
import UsuarioFamiliarModal from './usuarios/UsuarioFamiliarModal';

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
  const [userToDelete, setUserToDelete] = useState(null);
  const [isDeleting, setIsDeleting] = useState(false);
  const [familiarUserModal, setFamiliarUserModal] = useState(null);
  const [showGeneralFamiliarModal, setShowGeneralFamiliarModal] = useState(false);

  // Notifications and row action loaders
  const [successToast, setSuccessToast] = useState(null);
  const [actionLoadingId, setActionLoadingId] = useState(null);

  /**
   * Carga de usuarios desde la vista 'vista_usuarios' de Supabase
   */
  const loadUsuarios = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await fetchUsuarios();
      setUsuarios(data);
    } catch (err) {
      console.error('Error fetching users from vista_usuarios:', err);
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

  /**
   * Modificar estado activo/inactivo (HU4)
   */
  const handleToggleStatus = async (user) => {
    const nextState = !user.activo;
    const displayName = user.nombre_completo || `${user.nombre || user.nombres || ''} ${user.apellidos || ''}`.trim();
    try {
      setActionLoadingId(user.id_usuario);
      await toggleUserStatus(user.id_usuario, nextState);
      showToast(`Acceso ${nextState ? 'activado' : 'anulado'} para ${displayName}.`);
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

  /**
   * Eliminar usuario de forma permanente
   */
  const handleDeleteUser = async (userId) => {
    try {
      setIsDeleting(true);
      await deleteUserPermanently(userId);
      showToast('Usuario eliminado permanentemente.');
      setUserToDelete(null);
      setUsuarios((prev) => prev.filter((u) => u.id_usuario !== userId));
    } catch (err) {
      console.error('Error deleting user:', err);
      alert('Error al eliminar usuario.');
    } finally {
      setIsDeleting(false);
    }
  };

  /**
   * Filtrado dinámico por texto (nombre, apellidos, correo, CI, teléfono) y selectores
   */
  const filteredUsuarios = useMemo(() => {
    return usuarios.filter((u) => {
      const search = searchTerm.trim().toLowerCase();
      const firstName = (u.nombre || u.nombres || '').toLowerCase();
      const lastName = (u.apellidos || '').toLowerCase();
      const fullName = (u.nombre_completo || `${firstName} ${lastName}`).toLowerCase();
      const email = (u.email || '').toLowerCase();
      const ci = (u.ci_codigo || '').toLowerCase();
      const phone = (u.telefono || '').toString();

      const matchesSearch =
        !search ||
        firstName.includes(search) ||
        lastName.includes(search) ||
        fullName.includes(search) ||
        email.includes(search) ||
        ci.includes(search) ||
        phone.includes(search);

      const matchesRole = roleFilter === 'ALL' || u.rol === roleFilter;
      const matchesStatus =
        statusFilter === 'ALL' ||
        (statusFilter === 'ACTIVE' && u.activo !== false) ||
        (statusFilter === 'INACTIVE' && u.activo === false);

      return matchesSearch && matchesRole && matchesStatus;
    });
  }, [usuarios, searchTerm, roleFilter, statusFilter]);

  /**
   * Cálculo de métricas para las tarjetas superiores
   */
  const stats = useMemo(() => {
    const total = usuarios.length;
    const adminCount = usuarios.filter((u) => u.rol === 'Administrador').length;
    const empleadoCount = usuarios.filter((u) => u.rol === 'Empleado').length;
    const institucionCount = usuarios.filter((u) => u.rol === 'Institucion').length;
    const activos = usuarios.filter((u) => u.activo !== false).length;
    return { total, adminCount, empleadoCount, institucionCount, activos };
  }, [usuarios]);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      {/* Toast de confirmación flotante */}
      {successToast && (
        <div className="fixed bottom-5 right-5 z-50 bg-emerald-600 text-white px-5 py-3.5 rounded-xl shadow-2xl flex items-center space-x-3 animate-fade-in border border-emerald-400">
          <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
          <span className="text-sm font-medium">{successToast}</span>
        </div>
      )}

      {/* Encabezado de la página */}
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

        <div className="flex flex-wrap items-center gap-2.5">
          <button
            type="button"
            onClick={loadUsuarios}
            disabled={loading}
            className="p-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-600 transition shadow-xs"
            title="Refrescar datos"
          >
            <RefreshCw className={`w-5 h-5 ${loading ? 'animate-spin text-blue-600' : ''}`} />
          </button>

          <button
            type="button"
            onClick={() => setShowGeneralFamiliarModal(true)}
            className="flex items-center space-x-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold px-4 py-2.5 rounded-xl shadow-md hover:shadow-indigo-600/20 transform active:scale-95 transition-all duration-200"
            title="Registrar familiar para un empleado"
          >
            <Users className="w-5 h-5" />
            <span>Registrar Familiar</span>
          </button>
          
          <button
            type="button"
            onClick={() => setShowCreateModal(true)}
            className="flex items-center space-x-2 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold px-4 py-2.5 rounded-xl shadow-md hover:shadow-emerald-600/20 transform active:scale-95 transition-all duration-200"
          >
            <UserPlus className="w-5 h-5" />
            <span>Agregar Nuevo Usuario</span>
          </button>
        </div>
      </div>

      {/* Tarjetas de estadísticas */}
      <UsuariosStats stats={stats} />

      {/* Barra de búsqueda y filtros */}
      <UsuariosFilter
        searchTerm={searchTerm}
        onSearchChange={setSearchTerm}
        roleFilter={roleFilter}
        onRoleChange={setRoleFilter}
        statusFilter={statusFilter}
        onStatusChange={setStatusFilter}
      />

      {/* Tabla con listado de usuarios */}
      <UsuariosTable
        usuarios={filteredUsuarios}
        totalCount={usuarios.length}
        loading={loading}
        error={error}
        onRetry={loadUsuarios}
        actionLoadingId={actionLoadingId}
        onSelectDetails={setSelectedUser}
        onToggleStatus={handleToggleStatus}
        onDeleteClick={setUserToDelete}
        onManageFamiliares={(user) => setFamiliarUserModal(user)}
      />

      {/* Modal: Crear usuario (reutiliza Modal.js) */}
      <UsuarioCreateModal
        isOpen={showCreateModal}
        onClose={() => setShowCreateModal(false)}
        onUserCreated={loadUsuarios}
        showToast={showToast}
      />

      {/* Modal: Ver detalles de usuario (reutiliza Modal.js) */}
      <UsuarioDetailsModal
        isOpen={!!selectedUser}
        user={selectedUser}
        onClose={() => setSelectedUser(null)}
        onOpenFamiliares={(user) => setFamiliarUserModal(user)}
      />

      {/* Modal: Confirmación para eliminar usuario (reutiliza Modal.js) */}
      <UsuarioDeleteModal
        isOpen={!!userToDelete}
        user={userToDelete}
        onClose={() => setUserToDelete(null)}
        onConfirm={handleDeleteUser}
        isDeleting={isDeleting}
      />

      {/* Modal: Gestión y registro de familiares para Empleados (reutiliza Modal.js) */}
      <UsuarioFamiliarModal
        isOpen={!!familiarUserModal || showGeneralFamiliarModal}
        employee={familiarUserModal}
        employees={usuarios.filter((u) => u.rol === 'Empleado')}
        onClose={() => {
          setFamiliarUserModal(null);
          setShowGeneralFamiliarModal(false);
        }}
        showToast={showToast}
      />
    </div>
  );
}
