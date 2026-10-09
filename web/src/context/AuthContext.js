import React, { createContext, useContext, useState, useEffect } from 'react';
import { supabase, loginWithEmail, logout as supabaseLogout } from '../lib/supabaseClient';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [authError, setAuthError] = useState(null);

  // Initialize session and listen to auth changes
  useEffect(() => {
    async function loadSession() {
      try {
        setLoading(true);
        const { data: { session } } = await supabase.auth.getSession();
        if (session?.user) {
          setUser(session.user);
          await fetchProfile(session.user.id);
        } else {
          setUser(null);
          setProfile(null);
        }
      } catch (err) {
        console.error('Error loading session:', err);
      } finally {
        setLoading(false);
      }
    }

    loadSession();

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (session?.user) {
        setUser(session.user);
        await fetchProfile(session.user.id);
      } else {
        setUser(null);
        setProfile(null);
      }
      setLoading(false);
    });

    return () => {
      subscription?.unsubscribe();
    };
  }, []);

  async function fetchProfile(userId) {
    try {
      const { data, error } = await supabase
        .from('usuario')
        .select('*')
        .eq('id_usuario', userId)
        .maybeSingle();

      if (!error && data) {
        setProfile(data);
      }
    } catch (err) {
      console.error('Error fetching profile:', err);
    }
  }

  const login = async (email, password) => {
    setAuthError(null);
    try {
      const result = await loginWithEmail(email, password);
      setUser(result.user);
      setProfile(result.profile);
      return result;
    } catch (err) {
      setAuthError(err.message || 'Credenciales inválidas');
      throw err;
    }
  };

  const logout = async () => {
    try {
      await supabaseLogout();
      setUser(null);
      setProfile(null);
    } catch (err) {
      console.error('Error during logout:', err);
    }
  };

  const refreshProfile = async () => {
    if (user?.id) {
      await fetchProfile(user.id);
    }
  };

  const role = profile?.rol || user?.user_metadata?.rol || 'Empleado';
  const isAdmin = role === 'Administrador';

  return (
    <AuthContext.Provider
      value={{
        user,
        profile,
        role,
        isAdmin,
        loading,
        authError,
        login,
        logout,
        refreshProfile,
        setProfile,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
