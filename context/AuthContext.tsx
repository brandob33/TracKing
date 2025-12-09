import { useRouter, useSegments } from 'expo-router';
import React, { createContext, useContext, useEffect, useState } from 'react';

// User Types
type UserRole = 'athlete' | 'coach' | 'coach_admin';

interface User {
    email: string;
    name: string;
    role: UserRole;
}

interface AuthContextType {
    user: User | null;
    isLoading: boolean;
    signIn: (email: string, pass: string) => Promise<boolean>;
    signUp: (email: string, pass: string) => Promise<boolean>;
    signOut: () => void;
}

const AuthContext = createContext<AuthContextType>({
    user: null,
    isLoading: true,
    signIn: async () => false,
    signUp: async () => false,
    signOut: () => { },
});

export const useAuth = () => useContext(AuthContext);

export function AuthProvider({ children }: { children: React.ReactNode }) {
    const [user, setUser] = useState<User | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const router = useRouter();
    const segments = useSegments();

    // Simulate checking for a persisted session on mount
    useEffect(() => {
        setTimeout(() => {
            setIsLoading(false);
        }, 500);
    }, []);

    // Protected Routes Logic
    useEffect(() => {
        if (isLoading) return;

        const inAuthGroup = segments[0] === 'auth';

        if (!user && !inAuthGroup) {
            // Redirect to sign-in if not logged in
            router.replace('/auth/sign-in');
        } else if (user && inAuthGroup) {
            // Redirect to appropriate dashboard if logged in
            if (user.role === 'coach' || user.role === 'coach_admin') {
                router.replace('/coach');
            } else {
                router.replace('/(tabs)');
            }
        }
    }, [user, segments, isLoading]);

    const signIn = async (email: string, pass: string): Promise<boolean> => {
        // Mock Authentication Logic
        // In a real app, this would hit an API

        return new Promise((resolve) => {
            setTimeout(() => {
                if (email === 'athlete' && pass === 'athlete123') {
                    setUser({ email, name: 'Brandon (Athlete)', role: 'athlete' });
                    resolve(true);
                } else if (email === 'coach' && pass === 'coach123') {
                    setUser({ email, name: 'Coach Smith', role: 'coach_admin' });
                    resolve(true);
                } else {
                    resolve(false);
                }
            }, 800); // Fake network delay
        });
    };

    const signUp = async (email: string, pass: string): Promise<boolean> => {
        return new Promise((resolve) => {
            setTimeout(() => {
                // Default new sign-ups to Athlete for this demo
                setUser({ email, name: 'New Athlete', role: 'athlete' });
                resolve(true);
            }, 800);
        });
    };

    const signOut = () => {
        setUser(null);
    };

    return (
        <AuthContext.Provider value={{ user, isLoading, signIn, signUp, signOut }}>
            {children}
        </AuthContext.Provider>
    );
}
