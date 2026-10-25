import { supabase } from './supabaseClient';

/**
 * Extrae la ruta interna del bucket 'imagenes' a partir de una URL pública
 */
export function extractStoragePath(imageUrlOrPath) {
  if (!imageUrlOrPath || typeof imageUrlOrPath !== 'string') return null;
  const marker = '/imagenes/';
  const idx = imageUrlOrPath.indexOf(marker);
  if (idx !== -1) {
    return decodeURIComponent(imageUrlOrPath.substring(idx + marker.length));
  }
  if (imageUrlOrPath.startsWith('platos/')) {
    return imageUrlOrPath;
  }
  return null;
}

/**
 * Servicio para la gestión de Platos
 * Tabla: plato (id_plato, nombre, descripcion, imagen_url)
 */
export class Platos {
  /**
   * Sube una imagen al bucket 'imagenes' dentro del directorio 'platos'
   * @param {File|Blob} file
   * @returns {Promise<{ filePath: string, publicUrl: string }>}
   */
  async uploadPlatoImage(file) {
    if (!file) throw new Error('No se proporcionó ningún archivo para subir.');

    const ext = file.type === 'image/webp' ? 'webp' : (file.name?.split('.').pop() || 'webp');
    const cleanName = `plato_${Date.now()}_${Math.random().toString(36).substring(2, 8)}.${ext}`;
    const filePath = `platos/${cleanName}`;

    const { error } = await supabase.storage
      .from('imagenes')
      .upload(filePath, file, {
        cacheControl: '3600',
        upsert: false,
        contentType: file.type || 'image/webp',
      });

    if (error) {
      throw new Error(`Error al subir la imagen al bucket: ${error.message}`);
    }

    const { data: urlData } = supabase.storage
      .from('imagenes')
      .getPublicUrl(filePath);

    return { filePath, publicUrl: urlData.publicUrl };
  }

  /**
   * Elimina una imagen del bucket de Supabase
   * @param {string} imageUrlOrPath
   */
  async deletePlatoImage(imageUrlOrPath) {
    const path = extractStoragePath(imageUrlOrPath);
    if (!path) return;

    const { error } = await supabase.storage
      .from('imagenes')
      .remove([path]);

    if (error) {
      console.warn(`No se pudo eliminar la imagen previa de storage (${path}):`, error.message);
    }
  }

  /**
   * Crea un nuevo plato con soporte atómico para imagen:
   * Si se incluye una imagen, se sube primero; si la inserción en BD falla,
   * se realiza rollback inmediato eliminando la imagen del bucket.
   * 
   * @param {Object} platoData { nombre, descripcion, ... }
   * @param {File|Blob} [imageFile] Archivo de imagen comprimido opcional
   */
  async createPlato(platoData, imageFile = null) {
    let uploadedPath = null;
    let finalData = { ...platoData };

    if (imageFile) {
      const { filePath, publicUrl } = await this.uploadPlatoImage(imageFile);
      uploadedPath = filePath;
      finalData.imagen_url = publicUrl;
    }

    try {
      const { data, error } = await supabase
        .from('plato')
        .insert(finalData)
        .select()
        .single();

      if (error) throw error;
      return data;
    } catch (dbError) {
      // ROLLBACK: si la consulta a la base de datos falla, la imagen no se queda en el bucket
      if (uploadedPath) {
        console.warn('Fallo la creación del plato en BD. Ejecutando rollback de imagen:', uploadedPath);
        await this.deletePlatoImage(uploadedPath).catch(console.error);
      }
      throw dbError;
    }
  }

  /**
   * Actualiza un plato existente con soporte atómico para reemplazar o eliminar imagen.
   * 
   * @param {number|string} id_plato
   * @param {Object} updateData { nombre, descripcion, ... }
   * @param {File|Blob|null} [newImageFile] Nueva imagen a subir
   * @param {boolean} [removeCurrentImage=false] Indica si se debe eliminar la imagen actual
   * @param {string} [currentImageUrl=null] URL de la imagen actual para limpieza
   */
  async updatePlato(id_plato, updateData, newImageFile = null, removeCurrentImage = false, currentImageUrl = null) {
    let uploadedPath = null;
    let finalUpdate = { ...updateData };

    if (newImageFile) {
      const { filePath, publicUrl } = await this.uploadPlatoImage(newImageFile);
      uploadedPath = filePath;
      finalUpdate.imagen_url = publicUrl;
    } else if (removeCurrentImage) {
      finalUpdate.imagen_url = null;
    }

    try {
      const { data, error } = await supabase
        .from('plato')
        .update(finalUpdate)
        .eq('id_plato', id_plato)
        .select()
        .single();

      if (error) throw error;

      // Si la actualización en BD fue exitosa y se reemplazó o eliminó la imagen previa,
      // limpiamos la imagen vieja del bucket
      if ((newImageFile || removeCurrentImage) && currentImageUrl) {
        await this.deletePlatoImage(currentImageUrl).catch(console.error);
      }

      return data;
    } catch (dbError) {
      // ROLLBACK: si la actualización en BD falla, eliminamos la nueva imagen subida
      if (uploadedPath) {
        console.warn('Fallo la actualización del plato en BD. Ejecutando rollback de nueva imagen:', uploadedPath);
        await this.deletePlatoImage(uploadedPath).catch(console.error);
      }
      throw dbError;
    }
  }

  /**
   * Elimina un plato y su imagen asociada en el bucket de storage
   */
  async deletePlato(id_plato, currentImageUrl = null) {
    // 1. Eliminar relaciones en la tabla pivote menu_plato para evitar violación de FK
    await supabase
      .from('menu_plato')
      .delete()
      .eq('id_plato', id_plato);

    // 2. Eliminar el plato en BD
    const { error } = await supabase
      .from('plato')
      .delete()
      .eq('id_plato', id_plato);

    if (error) throw error;

    // 3. Limpiar imagen de storage si existía
    if (currentImageUrl) {
      await this.deletePlatoImage(currentImageUrl).catch(console.error);
    }

    return true;
  }

  async getPlatos() {
    const { data, error } = await supabase
      .from('plato')
      .select('*')
      .order('nombre', { ascending: true });

    if (error) throw error;
    return data || [];
  }

  async getPlatoById(id_plato) {
    const { data, error } = await supabase
      .from('plato')
      .select('*')
      .eq('id_plato', id_plato)
      .single();

    if (error) throw error;
    return data;
  }
}

/**
 * Servicio para la gestión del Menú del Día y la relación N:M con Platos
 * Tabla: menu_dia (id_menu, estado_publicacion [boolean], fecha)
 * Tabla: menu_plato (id_menuplato, id_plato, id_menu)
 */
export class MenuDia {
  async getMenuDias() {
    const { data, error } = await supabase
      .from('menu_dia')
      .select('*')
      .order('fecha', { ascending: true });
    if (error) throw error;
    return data || [];
  }

  async getMenuDiaById(id_menu) {
    const { data, error } = await supabase
      .from('menu_dia')
      .select('*')
      .eq('id_menu', id_menu)
      .single();
    if (error) throw error;
    return data;
  }

  async getMenuDiaByFecha(fecha) {
    const { data, error } = await supabase
      .from('menu_dia')
      .select('*')
      .eq('fecha', fecha)
      .maybeSingle();
    if (error) throw error;
    return data;
  }

  async createMenu(menuData) {
    const estadoBool = typeof menuData.estado_publicacion === 'boolean'
      ? menuData.estado_publicacion
      : (menuData.estado_publicacion === 'Publicado' || menuData.estado_publicacion === true);

    const { data, error } = await supabase
      .from('menu_dia')
      .insert({
        fecha: menuData.fecha,
        estado_publicacion: estadoBool,
      })
      .select();
    if (error) throw error;
    return data;
  }

  async updateMenu(id_menu, updateData) {
    const payload = { ...updateData };
    if ('estado_publicacion' in payload) {
      payload.estado_publicacion = typeof payload.estado_publicacion === 'boolean'
        ? payload.estado_publicacion
        : (payload.estado_publicacion === 'Publicado' || payload.estado_publicacion === true);
    }

    const { data, error } = await supabase
      .from('menu_dia')
      .update(payload)
      .eq('id_menu', id_menu)
      .select();
    if (error) throw error;
    return data;
  }

  async deleteMenu(id_menu) {
    // 1. Eliminar primero de la tabla pivote menu_plato (evita violación de FK menu_plato_id_menu_fkey)
    await supabase
      .from('menu_plato')
      .delete()
      .eq('id_menu', id_menu);

    // 2. Eliminar de menu_dia
    const { error } = await supabase
      .from('menu_dia')
      .delete()
      .eq('id_menu', id_menu);
    if (error) throw error;
    return true;
  }

  /**
   * Guarda o actualiza un menu_dia y sincroniza sus relaciones N:M en menu_plato
   * de forma diferencial (sin borrar a ciegas ni generar duplicados).
   */
  async guardarMenuCompleto({ id_menu, fecha, estado_publicacion, platosIds = [] }) {
    const estadoBool = typeof estado_publicacion === 'boolean'
      ? estado_publicacion
      : (estado_publicacion === 'Publicado' || estado_publicacion === true);

    let targetMenuId = id_menu;

    // Si no se proporcionó id_menu, verificar si ya existe un menu_dia para la fecha seleccionada
    if (!targetMenuId && fecha) {
      const { data: existingMenu, error: checkErr } = await supabase
        .from('menu_dia')
        .select('id_menu')
        .eq('fecha', fecha)
        .maybeSingle();

      if (!checkErr && existingMenu?.id_menu) {
        targetMenuId = existingMenu.id_menu;
      }
    }

    let menuResult = null;

    if (targetMenuId) {
      // Actualizar el menú existente
      const { data, error } = await supabase
        .from('menu_dia')
        .update({
          fecha,
          estado_publicacion: estadoBool,
        })
        .eq('id_menu', targetMenuId)
        .select()
        .single();

      if (error) throw error;
      menuResult = data;
    } else {
      // Crear un nuevo menu_dia primero
      const { data, error } = await supabase
        .from('menu_dia')
        .insert({
          fecha,
          estado_publicacion: estadoBool,
        })
        .select()
        .single();

      if (error) throw error;
      menuResult = data;
      targetMenuId = data.id_menu;
    }

    if (!targetMenuId) {
      throw new Error('No se pudo obtener el identificador (id_menu) del menú del día.');
    }

    // Sincronización diferencial en menu_plato:
    // Deduplicar platos solicitados por ID
    const targetPlatoIds = Array.from(new Set((platosIds || []).map(Number)));

    // Consultar las relaciones actuales de este menú
    const { data: existingRels, error: relsErr } = await supabase
      .from('menu_plato')
      .select('id_menuplato, id_plato')
      .eq('id_menu', targetMenuId);

    if (relsErr) {
      console.warn('Error al consultar relaciones previas en menu_plato:', relsErr.message);
    }

    const currentRels = existingRels || [];
    const currentPlatoIds = new Set(currentRels.map((r) => Number(r.id_plato)));

    // 1. Identificar registros a eliminar: platos ya no seleccionados o filas duplicadas existentes en BD
    const seenPids = new Set();
    const idsToDelete = [];
    for (const rel of currentRels) {
      const pid = Number(rel.id_plato);
      if (!targetPlatoIds.includes(pid) || seenPids.has(pid)) {
        idsToDelete.push(rel.id_menuplato);
      } else {
        seenPids.add(pid);
      }
    }

    if (idsToDelete.length > 0) {
      const { error: delError } = await supabase
        .from('menu_plato')
        .delete()
        .in('id_menuplato', idsToDelete);

      if (delError) {
        console.warn('Advertencia al eliminar platos desvinculados de menu_plato (posible falta de política RLS DELETE):', delError.message);
      }
    }

    // 2. Insertar únicamente platos NUEVOS que no estaban vinculados previamente
    const toInsert = targetPlatoIds.filter((pid) => !currentPlatoIds.has(pid));

    if (toInsert.length > 0) {
      const pivotRows = toInsert.map((id_plato) => ({
        id_menu: targetMenuId,
        id_plato: Number(id_plato),
      }));

      const { error: insMpError } = await supabase
        .from('menu_plato')
        .insert(pivotRows);

      if (insMpError) throw insMpError;
    }

    return menuResult;
  }

  /**
   * Guarda el menú completo de una semana en una sola llamada atómica mediante la función Supabase RPC
   * @param {Array<{ fecha: string, estado_publicacion: boolean, platos_ids: number[] }>} dias
   */
  async guardarMenuSemanal(dias) {
    if (!dias || dias.length === 0) {
      throw new Error('Debe proporcionar al menos un día para el menú semanal.');
    }

    // 1. Invocar la función RPC creada en Supabase (con p_dias)
    let lastError = null;
    try {
      const { data, error } = await supabase.rpc('guardar_menu_semanal', {
        p_dias: dias,
      });

      if (!error) return data;
      lastError = error;
    } catch (rpcErr) {
      lastError = rpcErr;
    }

    // 2. Intento secundario si el parámetro de la función se declaró como 'dias'
    try {
      const { data, error } = await supabase.rpc('guardar_menu_semanal', {
        dias: dias,
      });

      if (!error) return data;
      lastError = error;
    } catch (rpcErr2) {
      lastError = rpcErr2;
    }

    // 3. Fallback cliente si no se pudo ejecutar el RPC
    console.warn('Ejecutando guardado de respaldo cliente:', lastError?.message);
    for (const dia of dias) {
      await this.guardarMenuCompleto({
        fecha: dia.fecha,
        estado_publicacion: dia.estado_publicacion,
        platosIds: dia.platos_ids || [],
      });
    }

    return { success: true, message: 'Menú semanal guardado exitosamente' };
  }

  /**
   * Obtiene todos los menú_dia junto con los platos asociados (relación N:M)
   * Deduplica platos garantizando unicidad por día.
   */
  async getMenuDiasConPlatos() {
    const { data: menus, error: menusErr } = await supabase
      .from('menu_dia')
      .select('*')
      .order('fecha', { ascending: true });

    if (menusErr) throw menusErr;
    if (!menus || menus.length === 0) return [];

    // Obtener los platos y las relaciones existentes
    const [menuPlatosRes, platosRes] = await Promise.all([
      supabase.from('menu_plato').select('*'),
      supabase.from('plato').select('*'),
    ]);

    const platosMap = new Map((platosRes.data || []).map((p) => [p.id_plato, p]));
    const relaciones = menuPlatosRes.data || [];

    return menus.map((menu) => {
      const seenPlatos = new Set();
      const platosAsociados = [];

      for (const rel of relaciones) {
        if (rel.id_menu === menu.id_menu) {
          const pid = Number(rel.id_plato);
          if (!seenPlatos.has(pid)) {
            seenPlatos.add(pid);
            const plato = platosMap.get(pid);
            if (plato) {
              platosAsociados.push(plato);
            }
          }
        }
      }

      return {
        ...menu,
        platos: platosAsociados,
      };
    });
  }
}

/**
 * Servicio para la tabla pivote menu_plato
 * Tabla: menu_plato (id_menuplato, id_plato, id_menu)
 */
export class MenuPlato {
  async getMenuPlatos() {
    const { data, error } = await supabase
      .from('menu_plato')
      .select('*');
    if (error) throw error;
    return data || [];
  }

  async getPlatosByMenuId(id_menu) {
    const { data, error } = await supabase
      .from('menu_plato')
      .select('*, plato(*)')
      .eq('id_menu', id_menu);
    if (error) throw error;
    return data || [];
  }

  async createMenuPlato(menuPlatoData) {
    const { data, error } = await supabase
      .from('menu_plato')
      .insert(menuPlatoData)
      .select();
    if (error) throw error;
    return data;
  }

  async updateMenuPlato(id_menuplato, updateData) {
    const { data, error } = await supabase
      .from('menu_plato')
      .update(updateData)
      .eq('id_menuplato', id_menuplato)
      .select();
    if (error) throw error;
    return data;
  }

  async deleteMenuPlato(id_menuplato) {
    const { error } = await supabase
      .from('menu_plato')
      .delete()
      .eq('id_menuplato', id_menuplato);
    if (error) throw error;
    return true;
  }

  async deleteByMenuId(id_menu) {
    const { error } = await supabase
      .from('menu_plato')
      .delete()
      .eq('id_menu', id_menu);
    if (error) throw error;
    return true;
  }

  /**
   * Sincroniza los platos asignados a un menú del día específico (N:M)
   * Usa sincronización diferencial para evitar duplicados y preservar integridad.
   */
  async asociarPlatosAMenu(id_menu, platosIds = []) {
    if (!id_menu) {
      throw new Error('id_menu es requerido para asociar platos en menu_plato.');
    }

    const targetPlatoIds = Array.from(new Set((platosIds || []).map(Number)));

    // Obtener relaciones actuales
    const { data: existingRels, error: relsErr } = await supabase
      .from('menu_plato')
      .select('id_menuplato, id_plato')
      .eq('id_menu', id_menu);

    if (relsErr) {
      console.warn('Error al consultar relaciones previas en asociarPlatosAMenu:', relsErr.message);
    }

    const currentRels = existingRels || [];
    const currentPlatoIds = new Set(currentRels.map((r) => Number(r.id_plato)));

    // 1. Eliminar los que ya no están o duplicados
    const seenPids = new Set();
    const idsToDelete = [];
    for (const rel of currentRels) {
      const pid = Number(rel.id_plato);
      if (!targetPlatoIds.includes(pid) || seenPids.has(pid)) {
        idsToDelete.push(rel.id_menuplato);
      } else {
        seenPids.add(pid);
      }
    }

    if (idsToDelete.length > 0) {
      await supabase
        .from('menu_plato')
        .delete()
        .in('id_menuplato', idsToDelete);
    }

    // 2. Insertar únicamente los platos nuevos que no estaban asociados
    const toInsert = targetPlatoIds.filter((pid) => !currentPlatoIds.has(pid));
    if (toInsert.length > 0) {
      const records = toInsert.map((id_plato) => ({
        id_menu: id_menu,
        id_plato: Number(id_plato),
      }));

      const { data, error } = await supabase
        .from('menu_plato')
        .insert(records)
        .select();

      if (error) throw error;
      return data;
    }

    return [];
  }
}

// Instancias exportadas para conveniencia
export const platosService = new Platos();
export const menuDiaService = new MenuDia();
export const menuPlatoService = new MenuPlato();