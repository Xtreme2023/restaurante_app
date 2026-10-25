## Scripts Disponibles

En el directorio del proyecto, puedes ejecutar:

### `pnpm dev`

Inicia el servidor de desarrollo en Vite (`http://localhost:5173`).

### `pnpm build`

Compila el proyecto para producción en la carpeta `dist`.

## Variables de Entorno

Crea un archivo `.env` en la raíz de `/web` o configura en Vercel (Project Settings > Environment Variables):

```env
VITE_SUPABASE_URL=https://[YOUR_PROJECT_REF].supabase.co
VITE_SUPABASE_ANON_KEY=[YOUR_SUPABASE_ANON_KEY]
```

## Instalación de dependencias

```bash
pnpm install
```
