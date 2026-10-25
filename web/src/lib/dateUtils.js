/**
 * Utilidades seguras de fecha local (evita desfases de huso horario UTC)
 */

/**
 * Formatea un objeto Date en 'YYYY-MM-DD' en hora local
 */
export function formatLocalDate(date) {
  if (!date) return '';
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/**
 * Parsea un string 'YYYY-MM-DD' a un Date a mediodía local (12:00:00),
 * evitando desfases por huso horario o cambios de horario de verano.
 */
export function parseLocalDate(dateStr) {
  if (!dateStr) return new Date();
  const parts = dateStr.split('T')[0].split('-');
  if (parts.length === 3) {
    const [y, m, d] = parts.map(Number);
    return new Date(y, m - 1, d, 12, 0, 0);
  }
  return new Date(dateStr);
}

/**
 * Obtiene el lunes de la semana correspondiente a una fecha dada en formato 'YYYY-MM-DD'.
 * Reglas de negocio:
 * - Si cae en Sábado (6) -> Salta automáticamente al Lunes siguiente (+2 días).
 * - Si cae en Domingo (0) -> Salta automáticamente al Lunes siguiente (+1 día).
 * - Si cae de Lunes a Viernes (1..5) -> Se ubica en el Lunes de esa misma semana.
 */
export function getMondayOfWeek(inputDate = new Date()) {
  let date;
  if (typeof inputDate === 'string') {
    date = parseLocalDate(inputDate);
  } else {
    date = new Date(inputDate.getFullYear(), inputDate.getMonth(), inputDate.getDate(), 12, 0, 0);
  }

  const dayOfWeek = date.getDay(); // 0 = Domingo, 1 = Lunes, ..., 6 = Sábado

  if (dayOfWeek === 6) {
    // Sábado -> Salta al lunes siguiente
    date.setDate(date.getDate() + 2);
  } else if (dayOfWeek === 0) {
    // Domingo -> Salta al lunes siguiente
    date.setDate(date.getDate() + 1);
  } else {
    // Lunes a Viernes -> Lunes de esta semana
    const diff = date.getDate() - (dayOfWeek - 1);
    date.setDate(diff);
  }

  return formatLocalDate(date);
}

/**
 * Genera los 5 días hábiles (Lunes a Viernes) para una semana dada por su fecha de lunes.
 */
export function generateWeekDays(mondayStr) {
  const monday = parseLocalDate(mondayStr);
  const dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

  return dayNames.map((name, index) => {
    const cur = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + index, 12, 0, 0);
    const dateStr = formatLocalDate(cur);
    return {
      index,
      dayName: name,
      dateStr,
      displayDate: cur.toLocaleDateString('es-ES', { day: 'numeric', month: 'short' }),
      dateObj: cur,
    };
  });
}
