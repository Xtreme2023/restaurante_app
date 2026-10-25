import React, { useState, useMemo, useRef } from 'react';
import Modal from '../Modal';
import { platosService } from '../../lib/menu';
import { 
  compressImage, 
  revokePreview, 
  IMAGE_CONSTRAINTS 
} from '../../controllers/imageCompressor';
import { 
  ChefHat, 
  Plus, 
  Search, 
  Edit3, 
  Trash2, 
  UtensilsCrossed, 
  AlertCircle,
  UploadCloud,
  RefreshCw,
  Sparkles,
  Check
} from 'lucide-react';

export default function PlatosCatalogo({
  platos = [],
  onRefresh,
  showToast,
}) {
  const [searchPlato, setSearchPlato] = useState('');

  // Modales y Formulario
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingPlato, setEditingPlato] = useState(null);
  const [formData, setFormData] = useState({ nombre: '', descripcion: '' });
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState(null);

  // Estado para la gestión de la imagen (compresión y manipulación)
  const [imageState, setImageState] = useState({
    file: null,              // Archivo comprimido listo para subir
    previewUrl: null,        // Vista previa (blob o URL existente)
    originalSizeMB: null,    // Tamaño antes de compresión (MB)
    compressedSizeMB: null,  // Tamaño después de compresión (MB)
    savingsPercent: null,    // Ahorro porcentual de tamaño
    isExisting: false,       // true si es la imagen ya guardada en BD
    toDelete: false,         // true si se marcó para eliminar
    isCompressing: false,    // true durante la compresión con Canvas
  });

  const fileInputRef = useRef(null);
  const [deletingPlato, setDeletingPlato] = useState(null);

  // Apertura de modal en modo Crear
  const handleOpenCreate = () => {
    if (imageState.previewUrl && !imageState.isExisting) {
      revokePreview(imageState.previewUrl);
    }
    setEditingPlato(null);
    setFormData({ nombre: '', descripcion: '' });
    setImageState({
      file: null,
      previewUrl: null,
      originalSizeMB: null,
      compressedSizeMB: null,
      savingsPercent: null,
      isExisting: false,
      toDelete: false,
      isCompressing: false,
    });
    setFormError(null);
    setIsModalOpen(true);
  };

  // Apertura de modal en modo Editar
  const handleOpenEdit = (plato) => {
    if (imageState.previewUrl && !imageState.isExisting) {
      revokePreview(imageState.previewUrl);
    }
    setEditingPlato(plato);
    setFormData({ nombre: plato.nombre, descripcion: plato.descripcion || '' });
    setImageState({
      file: null,
      previewUrl: plato.imagen_url || null,
      originalSizeMB: null,
      compressedSizeMB: null,
      savingsPercent: null,
      isExisting: Boolean(plato.imagen_url),
      toDelete: false,
      isCompressing: false,
    });
    setFormError(null);
    setIsModalOpen(true);
  };

  // Cierre de modal con limpieza de recursos
  const handleCloseModal = () => {
    if (imageState.previewUrl && !imageState.isExisting) {
      revokePreview(imageState.previewUrl);
    }
    setIsModalOpen(false);
  };

  // Selección y compresión automática de imagen (mediante imageCompressor)
  const handleImageSelect = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (imageState.previewUrl && !imageState.isExisting) {
      revokePreview(imageState.previewUrl);
    }

    setImageState((prev) => ({
      ...prev,
      isCompressing: true,
      toDelete: false,
    }));
    setFormError(null);

    try {
      const result = await compressImage(file, {
        maxSizeMB: IMAGE_CONSTRAINTS.MAX_SIZE_MB,
        quality: 0.8,
        outputFormat: 'image/webp',
      });

      setImageState({
        file: result.file,
        previewUrl: result.previewUrl,
        originalSizeMB: result.originalSizeMB,
        compressedSizeMB: result.compressedSizeMB,
        savingsPercent: result.savingsPercent,
        isExisting: false,
        toDelete: false,
        isCompressing: false,
      });
    } catch (err) {
      console.error('Error al procesar la imagen:', err);
      setFormError(err.message || 'Error al comprimir la imagen.');
      setImageState((prev) => ({
        ...prev,
        isCompressing: false,
      }));
    } finally {
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  // Quitar la imagen seleccionada o marcar la existente para borrar
  const handleRemoveImage = () => {
    if (imageState.previewUrl && !imageState.isExisting) {
      revokePreview(imageState.previewUrl);
    }
    setImageState({
      file: null,
      previewUrl: null,
      originalSizeMB: null,
      compressedSizeMB: null,
      savingsPercent: null,
      isExisting: false,
      toDelete: true,
      isCompressing: false,
    });
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  // Guardar (Crear o Actualizar) con soporte atómico y rollback
  const handleSave = async (e) => {
    e.preventDefault();
    if (!formData.nombre.trim()) {
      setFormError('El nombre del plato es obligatorio.');
      return;
    }

    setSubmitting(true);
    setFormError(null);

    try {
      if (editingPlato) {
        await platosService.updatePlato(
          editingPlato.id_plato,
          {
            nombre: formData.nombre.trim(),
            descripcion: formData.descripcion.trim(),
          },
          imageState.file, // Nueva imagen comprimida (si se seleccionó)
          imageState.toDelete, // Si se marcó quitar la imagen
          editingPlato.imagen_url // URL previa para limpiar en storage
        );
        showToast?.(`Plato "${formData.nombre}" actualizado.`);
      } else {
        await platosService.createPlato(
          {
            nombre: formData.nombre.trim(),
            descripcion: formData.descripcion.trim(),
          },
          imageState.file // Imagen comprimida
        );
        showToast?.(`Plato "${formData.nombre}" agregado al catálogo.`);
      }

      handleCloseModal();
      await onRefresh?.();
    } catch (err) {
      console.error('Error al guardar plato:', err);
      setFormError(err.message || 'Error al guardar plato.');
    } finally {
      setSubmitting(false);
    }
  };

  // Confirmar eliminación del plato y su imagen en storage
  const handleDeleteConfirm = async () => {
    if (!deletingPlato) return;
    try {
      await platosService.deletePlato(deletingPlato.id_plato, deletingPlato.imagen_url);
      showToast?.(`Plato "${deletingPlato.nombre}" eliminado.`);
      setDeletingPlato(null);
      await onRefresh?.();
    } catch (err) {
      console.error('Error al eliminar plato:', err);
      alert('Error al eliminar plato: ' + (err.message || 'Error desconocido'));
    }
  };

  const filteredPlatos = useMemo(() => {
    if (!searchPlato.trim()) return platos;
    const q = searchPlato.toLowerCase();
    return platos.filter(
      (p) => p.nombre?.toLowerCase().includes(q) || p.descripcion?.toLowerCase().includes(q)
    );
  }, [platos, searchPlato]);

  return (
    <div className="space-y-6">
      {/* Barra de Acciones y Búsqueda */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-sm flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchPlato}
            onChange={(e) => setSearchPlato(e.target.value)}
            placeholder="Buscar plato por nombre o descripción..."
            className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white"
          />
        </div>

        <button
          type="button"
          onClick={handleOpenCreate}
          className="flex items-center space-x-2 bg-blue-600 hover:bg-blue-700 text-white font-semibold px-4 py-2.5 rounded-xl shadow-md transition transform active:scale-95 text-sm"
        >
          <Plus className="w-4 h-4" />
          <span>Agregar Plato al Catálogo</span>
        </button>
      </div>

      {/* Grid de Platos */}
      {filteredPlatos.length === 0 ? (
        <div className="bg-white rounded-2xl p-12 text-center border border-slate-200 shadow-sm">
          <ChefHat className="w-12 h-12 text-slate-300 mx-auto mb-2" />
          <h3 className="text-base font-bold text-slate-700">No se encontraron platos</h3>
          <p className="text-xs text-slate-400 mt-1">
            {searchPlato ? 'No hay coincidencias con tu búsqueda.' : 'Aún no has registrado platos en el catálogo.'}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {filteredPlatos.map((plato) => (
            <div
              key={plato.id_plato}
              className="bg-white rounded-2xl border border-slate-200/80 shadow-xs hover:shadow-md transition flex flex-col justify-between overflow-hidden group"
            >
              <div>
                {/* Cabecera visual con Imagen o Icono */}
                {plato.imagen_url ? (
                  <div className="relative h-44 w-full bg-slate-100 overflow-hidden flex items-center justify-center">
                    <div className="absolute inset-0 flex flex-col items-center justify-center text-slate-300">
                      <UtensilsCrossed className="w-8 h-8 mb-1 opacity-40" />
                      <span className="text-[10px] text-slate-400 font-medium">Plato</span>
                    </div>
                    <img
                      src={plato.imagen_url}
                      alt={plato.nombre}
                      className="relative z-1 w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                      loading="lazy"
                      onError={(e) => {
                        e.currentTarget.style.display = 'none';
                      }}
                    />
                    <div className="absolute top-2.5 right-2.5 flex items-center space-x-1 bg-white/90 backdrop-blur-xs p-1 rounded-xl shadow-sm">
                      <button
                        type="button"
                        onClick={() => handleOpenEdit(plato)}
                        className="p-1.5 text-slate-600 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition"
                        title="Editar plato e imagen"
                      >
                        <Edit3 className="w-3.5 h-3.5" />
                      </button>
                      <button
                        type="button"
                        onClick={() => setDeletingPlato(plato)}
                        className="p-1.5 text-slate-600 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
                        title="Eliminar plato"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="p-5 pb-0 flex items-start justify-between gap-2">
                    <div className="p-2.5 bg-blue-50 text-blue-600 rounded-xl">
                      <UtensilsCrossed className="w-5 h-5" />
                    </div>
                    <div className="flex items-center space-x-1">
                      <button
                        type="button"
                        onClick={() => handleOpenEdit(plato)}
                        className="p-1.5 text-slate-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition"
                        title="Editar plato"
                      >
                        <Edit3 className="w-3.5 h-3.5" />
                      </button>
                      <button
                        type="button"
                        onClick={() => setDeletingPlato(plato)}
                        className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
                        title="Eliminar plato"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                )}

                <div className="p-5 pt-3">
                  <h4 className="text-base font-bold text-slate-900 leading-snug">{plato.nombre}</h4>
                  <p className="text-xs text-slate-500 mt-1 line-clamp-3">
                    {plato.descripcion || 'Sin descripción detallada.'}
                  </p>
                </div>
              </div>

              <div className="px-5 pb-4 pt-2 border-t border-slate-100 flex items-center justify-between text-[11px] text-slate-400">
                <span>Catálogo general</span>
                {/* <span className="font-mono">ID: #{plato.id_plato}</span> */}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal: Crear / Editar Plato con Gestión de Imagen */}
      <Modal
        isOpen={isModalOpen}
        onClose={handleCloseModal}
        title={editingPlato ? 'Editar Plato' : 'Nuevo Plato'}
        subtitle="Administra los detalles de la comida y su fotografía para el menú institucional"
        icon={ChefHat}
        maxWidth="max-w-lg"
      >
        <form onSubmit={handleSave} className="space-y-4">
          {formError && (
            <div className="p-3 bg-rose-50 border border-rose-200 rounded-xl text-rose-700 text-xs flex items-center space-x-2">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              <span>{formError}</span>
            </div>
          )}

          {/* Campo: Nombre */}
          <div>
            <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
              Nombre del Plato *
            </label>
            <input
              type="text"
              required
              value={formData.nombre}
              onChange={(e) => setFormData({ ...formData, nombre: e.target.value })}
              placeholder="Ej. Pollo a la plancha con guarnición"
              className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Campo: Descripción */}
          <div>
            <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
              Descripción / Ingredientes (Opcional)
            </label>
            <textarea
              rows={2}
              value={formData.descripcion}
              onChange={(e) => setFormData({ ...formData, descripcion: e.target.value })}
              placeholder="Ej. Incluye ensalada mixta fresca, arroz primavera y postre del día."
              className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Campo: Imagen del Plato con Compresión Automática */}
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-xs font-bold text-slate-700 uppercase tracking-wider">
                Fotografía del Plato (Opcional)
              </label>
              <span className="text-[11px] text-slate-400">
                Solo en MB (Máx. {IMAGE_CONSTRAINTS.MAX_SIZE_MB} MB)
              </span>
            </div>

            <input
              ref={fileInputRef}
              type="file"
              accept="image/jpeg,image/png,image/webp,image/jpg"
              onChange={handleImageSelect}
              className="hidden"
            />

            {/* Estado A: Comprimiendo en Canvas */}
            {imageState.isCompressing ? (
              <div className="border-2 border-dashed border-blue-300 bg-blue-50/50 rounded-2xl p-6 text-center space-y-2">
                <div className="w-8 h-8 border-3 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto" />
                <p className="text-xs font-semibold text-blue-700">Comprimiendo y optimizando imagen...</p>
                <p className="text-[11px] text-slate-500">Reduciendo tamaño para almacenamiento eficiente</p>
              </div>
            ) : imageState.previewUrl && !imageState.toDelete ? (
              /* Estado B: Vista previa con opciones de Editar/Quitar/Cambiar */
              <div className="space-y-2">
                <div className="relative rounded-2xl overflow-hidden border border-slate-200 bg-slate-900 group">
                  <img
                    src={imageState.previewUrl}
                    alt="Vista previa del plato"
                    className="w-full h-44 object-cover"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent flex items-end justify-between p-3">
                    {/* <div className="text-white text-[11px]">
                      {imageState.isExisting ? (
                        <span className="bg-slate-900/80 backdrop-blur-xs px-2 py-0.5 rounded-md font-medium border border-white/20">
                          Imagen actual en catálogo
                        </span>
                      ) : (
                        <span className="bg-emerald-600/90 backdrop-blur-xs px-2 py-0.5 rounded-md font-medium inline-flex items-center">
                          <Sparkles className="w-3 h-3 mr-1" />
                          Optimizada: {imageState.compressedSizeMB} MB
                        </span>
                      )}
                    </div> */}
                    <div className="flex items-center space-x-1.5">
                      <button
                        type="button"
                        onClick={() => fileInputRef.current?.click()}
                        className="px-2.5 py-1.5 bg-white/95 hover:bg-white text-slate-800 text-xs font-semibold rounded-lg shadow-sm transition flex items-center space-x-1"
                        title="Subir otra imagen"
                      >
                        <RefreshCw className="w-3 h-3 text-blue-600" />
                        <span>Cambiar</span>
                      </button>
                      <button
                        type="button"
                        onClick={handleRemoveImage}
                        className="px-2.5 py-1.5 bg-rose-600 hover:bg-rose-700 text-white text-xs font-semibold rounded-lg shadow-sm transition flex items-center space-x-1"
                        title="Eliminar imagen"
                      >
                        <Trash2 className="w-3 h-3" />
                        <span>Quitar</span>
                      </button>
                    </div>
                  </div>
                </div>

                {/* Métricas de ahorro de compresión 
                {!imageState.isExisting && imageState.originalSizeMB && (
                  <div className="p-2.5 bg-emerald-50/90 border border-emerald-200 rounded-xl flex items-center justify-between text-xs text-emerald-800">
                    <div className="flex items-center space-x-1.5">
                      <Check className="w-4 h-4 text-emerald-600 flex-shrink-0" />
                      <span>
                        Original: <strong>{imageState.originalSizeMB} MB</strong> → Comprimido: <strong>{imageState.compressedSizeMB} MB</strong>
                      </span>
                    </div>
                    <span className="font-extrabold text-[11px] bg-emerald-200 text-emerald-800 px-2 py-0.5 rounded-full">
                      -{imageState.savingsPercent}%
                    </span>
                  </div>
                )}*/}
              </div>
            ) : (
              /* Estado C: Dropzone para cargar imagen */
              <div
                onClick={() => fileInputRef.current?.click()}
                className="border-2 border-dashed border-slate-200 hover:border-blue-400 bg-slate-50 hover:bg-blue-50/30 rounded-2xl p-6 text-center cursor-pointer transition group"
              >
                <div className="w-10 h-10 rounded-xl bg-blue-100/70 text-blue-600 flex items-center justify-center mx-auto mb-2 group-hover:scale-105 transition-transform">
                  <UploadCloud className="w-5 h-5" />
                </div>
                <p className="text-xs font-bold text-slate-700 group-hover:text-blue-600 transition-colors">
                  Haz clic para seleccionar o subir una imagen
                </p>
                <p className="text-[11px] text-slate-400 mt-1">
                  Formatos JPG, PNG o WebP (en MB). Se comprimirá automáticamente antes de subir.
                </p>
              </div>
            )}
          </div>

          {/* Botones de acción del Modal */}
          <div className="pt-2 flex items-center justify-end space-x-3 border-t border-slate-100">
            <button
              type="button"
              onClick={handleCloseModal}
              disabled={submitting}
              className="px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100 rounded-xl transition"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={submitting || imageState.isCompressing}
              className="px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-xl shadow-md transition disabled:opacity-50 flex items-center space-x-2"
            >
              {submitting && (
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
              )}
              <span>
                {submitting
                  ? 'Guardando...'
                  : editingPlato
                  ? 'Actualizar Plato'
                  : 'Guardar Plato'}
              </span>
            </button>
          </div>
        </form>
      </Modal>

      {/* Modal: Confirmar Eliminación */}
      <Modal
        isOpen={Boolean(deletingPlato)}
        onClose={() => setDeletingPlato(null)}
        title="¿Eliminar plato del catálogo?"
        subtitle="Esta acción desvinculará el plato de los menús y eliminará su imagen del almacenamiento"
        icon={Trash2}
        maxWidth="max-w-md"
      >
        <div className="space-y-4">
          <p className="text-sm text-slate-600">
            ¿Estás seguro de que deseas eliminar permanentemente el plato{' '}
            <strong>"{deletingPlato?.nombre}"</strong>?
          </p>

          <div className="flex items-center justify-end space-x-3 pt-2">
            <button
              type="button"
              onClick={() => setDeletingPlato(null)}
              className="px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100 rounded-xl transition"
            >
              Cancelar
            </button>
            <button
              type="button"
              onClick={handleDeleteConfirm}
              className="px-4 py-2 bg-rose-600 hover:bg-rose-700 text-white text-sm font-semibold rounded-xl shadow-sm transition"
            >
              Sí, Eliminar
            </button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
