/**
 * imageCompressor.js
 * Controlador especializado única y exclusivamente en la validación,
 * compresión y reducción de tamaño de imágenes en el navegador.
 */

export const IMAGE_CONSTRAINTS = {
  // Límite máximo de peso de imagen permitido (en Megabytes)
  MAX_SIZE_MB: 10,
  // Límite mínimo para considerar el archivo válido (0.01 MB ~ 10 KB)
  MIN_SIZE_MB: 0.01,
  // Dimensiones máximas recomendadas para catálogo web
  MAX_WIDTH: 1200,
  MAX_HEIGHT: 1200,
  // Calidad de compresión (0.1 a 1.0)
  QUALITY: 0.8,
  // Formatos MIME permitidos
  ALLOWED_TYPES: ['image/jpeg', 'image/png', 'image/webp', 'image/jpg'],
  // Formato preferido de salida para máxima compresión
  OUTPUT_FORMAT: 'image/webp',
};

/**
 * Convierte bytes a formato numérico de Megabytes con 2 decimales
 * @param {number} bytes
 * @returns {number}
 */
export function bytesToMB(bytes) {
  return Number((bytes / (1024 * 1024)).toFixed(2));
}

/**
 * Formatea un tamaño en bytes a string legible en MB
 * @param {number} bytes
 * @returns {string} Ej: "1.45 MB"
 */
export function formatSizeMB(bytes) {
  const mb = bytesToMB(bytes);
  return `${mb} MB`;
}

/**
 * Valida si un archivo cumple los criterios de tipo y tamaño en MB
 * @param {File} file
 * @param {Object} options
 * @returns {{ valid: boolean, error?: string, sizeMB: number }}
 */
export function validateImage(file, options = {}) {
  const maxMB = options.maxSizeMB || IMAGE_CONSTRAINTS.MAX_SIZE_MB;
  const minMB = options.minSizeMB || IMAGE_CONSTRAINTS.MIN_SIZE_MB;
  const allowedTypes = options.allowedTypes || IMAGE_CONSTRAINTS.ALLOWED_TYPES;

  if (!file) {
    return { valid: false, error: 'No se seleccionó ningún archivo de imagen.', sizeMB: 0 };
  }

  // 1. Validar tipo MIME
  if (!allowedTypes.includes(file.type)) {
    return {
      valid: false,
      error: 'Formato no permitido. Solo se aceptan imágenes JPG, PNG o WebP.',
      sizeMB: bytesToMB(file.size),
    };
  }

  const sizeMB = bytesToMB(file.size);

  // 2. Validar tamaño en MB
  if (sizeMB > maxMB) {
    return {
      valid: false,
      error: `La imagen pesa ${sizeMB} MB y excede el límite máximo permitido de ${maxMB} MB.`,
      sizeMB,
    };
  }

  if (sizeMB < minMB) {
    return {
      valid: false,
      error: `El archivo es demasiado pequeño o está dañado (${sizeMB} MB).`,
      sizeMB,
    };
  }

  return { valid: true, sizeMB };
}

/**
 * Controlador principal para comprimir una imagen en el cliente reduciendo su peso.
 * 
 * @param {File} file - Archivo de imagen seleccionado por el usuario
 * @param {Object} [options] - Parámetros de configuración opcionales
 * @param {number} [options.maxWidth=1200]
 * @param {number} [options.maxHeight=1200]
 * @param {number} [options.quality=0.8]
 * @param {string} [options.outputFormat='image/webp']
 * @param {number} [options.maxSizeMB=10]
 * @returns {Promise<{
 *   file: File,
 *   originalSizeMB: number,
 *   compressedSizeMB: number,
 *   savingsPercent: number,
 *   previewUrl: string,
 *   width: number,
 *   height: number
 * }>}
 */
export async function compressImage(file, options = {}) {
  // 1. Validación previa
  const validation = validateImage(file, options);
  if (!validation.valid) {
    throw new Error(validation.error);
  }

  const maxWidth = options.maxWidth || IMAGE_CONSTRAINTS.MAX_WIDTH;
  const maxHeight = options.maxHeight || IMAGE_CONSTRAINTS.MAX_HEIGHT;
  const quality = options.quality ?? IMAGE_CONSTRAINTS.QUALITY;
  const outputFormat = options.outputFormat || IMAGE_CONSTRAINTS.OUTPUT_FORMAT;

  return new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onerror = () => {
      reject(new Error('Error al leer el archivo de imagen.'));
    };

    reader.onload = (event) => {
      const img = new Image();

      img.onerror = () => {
        reject(new Error('No se pudo procesar la imagen seleccionada.'));
      };

      img.onload = () => {
        try {
          let { width, height } = img;

          // 2. Redimensionamiento manteniendo la proporción de aspecto
          if (width > maxWidth || height > maxHeight) {
            const ratio = Math.min(maxWidth / width, maxHeight / height);
            width = Math.round(width * ratio);
            height = Math.round(height * ratio);
          }

          // 3. Renderizado en Canvas con suavizado
          const canvas = document.createElement('canvas');
          canvas.width = width;
          canvas.height = height;

          const ctx = canvas.getContext('2d');
          if (!ctx) {
            throw new Error('No se pudo obtener el contexto 2D para compresión.');
          }

          ctx.imageSmoothingEnabled = true;
          ctx.imageSmoothingQuality = 'high';
          ctx.drawImage(img, 0, 0, width, height);

          // 4. Exportar a Blob comprimido
          canvas.toBlob(
            (blob) => {
              if (!blob) {
                reject(new Error('Falló la compresión de la imagen.'));
                return;
              }

              // Normalizar nombre con extensión adecuada
              const baseName = file.name.substring(0, file.name.lastIndexOf('.')) || 'plato';
              const ext = outputFormat === 'image/webp' ? 'webp' : 'jpg';
              const newFileName = `${baseName}_compressed.${ext}`;

              const compressedFile = new File([blob], newFileName, {
                type: outputFormat,
                lastModified: Date.now(),
              });

              const originalSizeMB = bytesToMB(file.size);
              const compressedSizeMB = bytesToMB(compressedFile.size);
              const savings = originalSizeMB > 0
                ? Math.round(((file.size - compressedFile.size) / file.size) * 100)
                : 0;

              const previewUrl = URL.createObjectURL(blob);

              resolve({
                file: compressedFile,
                originalSizeMB,
                compressedSizeMB,
                savingsPercent: Math.max(0, savings),
                previewUrl,
                width,
                height,
              });
            },
            outputFormat,
            quality
          );
        } catch (err) {
          reject(err);
        }
      };

      img.src = event.target.result;
    };

    reader.readAsDataURL(file);
  });
}

/**
 * Libera la memoria de una URL temporal creada con URL.createObjectURL
 * @param {string} url
 */
export function revokePreview(url) {
  if (url && typeof url === 'string' && url.startsWith('blob:')) {
    try {
      URL.revokeObjectURL(url);
    } catch (e) {
      // Ignorar si ya fue liberada
    }
  }
}
