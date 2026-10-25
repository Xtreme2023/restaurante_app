import React, { useEffect } from 'react';
import { X } from 'lucide-react';

/**
 * Componente Modal General y Reutilizable
 *
 * @param {boolean} isOpen - Controla la visibilidad del modal
 * @param {function} onClose - Función a ejecutar al cerrar
 * @param {React.ReactNode} title - Título del encabezado
 * @param {React.ReactNode} subtitle - Subtítulo o descripción opcional
 * @param {React.ElementType} icon - Ícono opcional de Lucide para el encabezado
 * @param {React.ReactNode} children - Contenido principal del modal
 * @param {React.ReactNode} footer - Acciones del pie de página opcionales
 * @param {string} maxWidth - Clase Tailwind para el ancho máximo (ej. 'max-w-xl', 'max-w-2xl')
 * @param {boolean} closeOnOverlayClick - Si hace clic fuera del modal lo cierra (por defecto: true)
 * @param {boolean} showCloseButton - Muestra el botón de cerrar 'X' (por defecto: true)
 */
export default function Modal({
  isOpen,
  onClose,
  title,
  subtitle,
  icon: Icon,
  children,
  footer,
  maxWidth = 'max-w-xl',
  closeOnOverlayClick = true,
  showCloseButton = true,
}) {
  // Manejo de la tecla Escape para cerrar el modal
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (e) => {
      if (e.key === 'Escape') {
        onClose?.();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  // Prevenir scroll en el fondo cuando el modal está abierto
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = 'unset';
    }
    return () => {
      document.body.style.overflow = 'unset';
    };
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 overflow-y-auto bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4 animate-fade-in"
      onClick={(e) => {
        if (closeOnOverlayClick && e.target === e.currentTarget) {
          onClose?.();
        }
      }}
      role="dialog"
      aria-modal="true"
    >
      <div
        className={`relative w-full ${maxWidth} bg-white rounded-2xl shadow-2xl overflow-hidden border border-slate-100 flex flex-col my-8 transform transition-all animate-scale-in`}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        {(title || showCloseButton) && (
          <div className="bg-gradient-to-r from-blue-700 via-blue-600 to-indigo-700 text-white px-6 py-4 flex items-center justify-between shadow-xs">
            <div className="flex items-center space-x-3">
              {Icon && (
                <div className="p-2 bg-white/15 rounded-xl backdrop-blur-sm text-white">
                  <Icon className="w-5 h-5 text-blue-100" />
                </div>
              )}
              <div>
                {title && (
                  <h3 className="text-lg font-bold tracking-tight text-white leading-snug">
                    {title}
                  </h3>
                )}
                {subtitle && (
                  <p className="text-xs text-blue-100/90 mt-0.5">
                    {subtitle}
                  </p>
                )}
              </div>
            </div>

            {showCloseButton && (
              <button
                type="button"
                onClick={onClose}
                className="text-white/80 hover:text-white p-1.5 rounded-lg hover:bg-white/10 transition-colors focus:outline-none"
                aria-label="Cerrar modal"
              >
                <X className="w-5 h-5" />
              </button>
            )}
          </div>
        )}

        {/* Body */}
        <div className="p-6 overflow-y-auto max-h-[calc(85vh-140px)] text-slate-700 space-y-4">
          {children}
        </div>

        {/* Footer */}
        {footer && (
          <div className="px-6 py-4 bg-slate-50 border-t border-slate-100 flex items-center justify-end space-x-3">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}
