import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { 
  Lock, 
  Mail, 
  Eye, 
  EyeOff, 
  LogIn, 
  UtensilsCrossed, 
  AlertCircle, 
  ShieldCheck,
  ChefHat
} from 'lucide-react';

export default function Login() {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErrorMessage('');

    if (!email.trim() || !password) {
      setErrorMessage('Por favor ingresa tu correo y contraseña.');
      return;
    }

    try {
      setLoading(true);
      await login(email.trim(), password);
    } catch (err) {
      console.error('Login error:', err);
      if (err.message?.includes('Invalid login credentials')) {
        setErrorMessage('Credenciales inválidas. Por favor revisa tu correo y contraseña.');
      } else if (err.message?.includes('desactivada')) {
        setErrorMessage(err.message);
      } else {
        setErrorMessage(err.message || 'Error al iniciar sesión. Inténtelo nuevamente.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div 
      className="relative min-h-screen w-full flex items-center justify-center p-4 bg-cover bg-center bg-no-repeat selection:bg-blue-500 selection:text-white"
      style={{
        backgroundImage: "url('/bg-restaurante.jpg'), url('https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1920&q=80')"
      }}
    >
      {/* Dark overlay with subtle backdrop blur matching original design */}
      <div className="absolute inset-0 bg-gradient-to-tr from-black/80 via-black/60 to-black/75 backdrop-blur-[2px]" />

      {/* Login Card with fadeInUp animation */}
      <div className="relative z-10 w-full max-w-md bg-white/95 backdrop-blur-xl rounded-2xl shadow-2xl overflow-hidden border border-white/40 animate-fade-in-up">
        {/* Card Header with Blue Theme */}
        <div className="bg-gradient-to-r from-blue-600 to-indigo-600 text-white p-6 sm:p-8 text-center relative">
          <div className="mx-auto w-16 h-16 rounded-2xl bg-white/15 backdrop-blur-md flex items-center justify-center mb-3 shadow-inner border border-white/20 transform transition hover:scale-105">
            <UtensilsCrossed className="w-8 h-8 text-white" />
          </div>
          <h2 className="text-2xl sm:text-3xl font-extrabold tracking-tight">Restaurante Cielo</h2>
          <p className="text-blue-100 text-sm mt-1 font-medium">Sistema de Gestión & Administración</p>

          <div className="absolute -bottom-3 left-1/2 transform -translate-x-1/2 bg-blue-50 text-blue-800 text-[11px] font-bold uppercase tracking-wider px-3 py-0.5 rounded-full shadow-sm border border-blue-200">
            Acceso al Sistema
          </div>
        </div>

        {/* Card Body */}
        <div className="p-6 sm:p-8 pt-7 bg-slate-50/80">
          {errorMessage && (
            <div className="mb-5 p-3.5 bg-rose-50 border border-rose-200 rounded-xl flex items-start space-x-2.5 text-rose-700 text-sm animate-fade-in">
              <AlertCircle className="w-5 h-5 flex-shrink-0 mt-0.5 text-rose-500" />
              <div className="leading-snug">
                <span className="font-semibold block">Error de autenticación:</span>
                <span>{errorMessage}</span>
              </div>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Email Field */}
            <div>
              <label htmlFor="email" className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Correo Electrónico / Usuario
              </label>
              <div className="relative rounded-xl shadow-sm">
                <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                  <Mail className="w-5 h-5" />
                </div>
                <input
                  id="email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="ejemplo@institucion.bo"
                  required
                  autoComplete="username"
                  className="block w-full pl-11 pr-4 py-3 bg-white border border-slate-300 rounded-xl text-slate-900 placeholder-slate-400 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-200 shadow-sm"
                />
              </div>
            </div>

            {/* Password Field */}
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label htmlFor="password" className="block text-xs font-bold text-slate-700 uppercase tracking-wider">
                  Contraseña
                </label>
              </div>
              <div className="relative rounded-xl shadow-sm">
                <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                  <Lock className="w-5 h-5" />
                </div>
                <input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  autoComplete="current-password"
                  className="block w-full pl-11 pr-11 py-3 bg-white border border-slate-300 rounded-xl text-slate-900 placeholder-slate-400 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-200 shadow-sm"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 right-0 pr-3.5 flex items-center text-slate-400 hover:text-slate-600 transition"
                  tabIndex={-1}
                >
                  {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                </button>
              </div>
            </div>

            {/* Submit Button */}
            <div className="pt-2">
              <button
                type="submit"
                disabled={loading}
                className="w-full flex items-center justify-center space-x-2 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white font-semibold py-3.5 px-4 rounded-xl shadow-lg shadow-blue-500/25 hover:shadow-blue-500/40 transform active:scale-[0.99] transition-all duration-200 disabled:opacity-60 disabled:cursor-not-allowed"
              >
                {loading ? (
                  <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                ) : (
                  <>
                    <LogIn className="w-5 h-5" />
                    <span>Ingresar</span>
                  </>
                )}
              </button>
            </div>
          </form>

          {/* Quick info / help section */}
          <div className="mt-6 pt-5 border-t border-slate-200 text-center">
            <div className="inline-flex items-center space-x-1.5 text-xs text-slate-500 bg-white px-3 py-1.5 rounded-full border border-slate-200 shadow-xs">
              <ShieldCheck className="w-4 h-4 text-blue-600" />
              <span>Acceso seguro protegido con Supabase Auth</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
