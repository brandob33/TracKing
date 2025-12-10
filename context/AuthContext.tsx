import { createUser } from '@/src/graphql/mutations';
import { getUser } from '@/src/graphql/queries';
import { generateClient } from 'aws-amplify/api';
import { signIn as amplifySignIn, signOut as amplifySignOut, signUp as amplifySignUp, confirmSignUp, fetchUserAttributes, getCurrentUser, resendSignUpCode } from 'aws-amplify/auth';
import { useRouter, useSegments } from 'expo-router';
import React, { createContext, useContext, useEffect, useState } from 'react';

// User Types
type UserRole = 'athlete' | 'coach' | 'coach_admin';

interface User {
    id: string;
    email: string;
    username: string;
    role: UserRole;
}

interface AuthContextType {
    user: User | null;
    isLoading: boolean;
    signIn: (email: string, pass: string, role?: UserRole) => Promise<boolean>;
    signUp: (email: string, pass: string, role?: UserRole) => Promise<{ isSignedUp: boolean; nextStep?: string }>;
    confirmUser: (email: string, code: string) => Promise<boolean>;
    signOut: () => void;
    completedWorkouts: string[];
    completeWorkout: (id: string) => void;
}

const AuthContext = createContext<AuthContextType>({
    user: null,
    isLoading: true,
    signIn: async () => false,
    signUp: async () => ({ isSignedUp: false }),
    confirmUser: async () => false,
    signOut: () => { },
    completedWorkouts: [],
    completeWorkout: () => { },
});

export const useAuth = () => useContext(AuthContext);

export function AuthProvider({ children }: { children: React.ReactNode }) {
    const [user, setUser] = useState<User | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const router = useRouter();
    const segments = useSegments();
    const client = generateClient();

    // Check for authenticated user on mount
    useEffect(() => {
        checkUser();
    }, []);

    const checkUser = async () => {
        try {
            console.log('Checking for current user...');
            const currentUser = await getCurrentUser();
            console.log('Current user from Cognito:', currentUser);
            const attributes = await fetchUserAttributes();
            console.log('User attributes:', attributes);

            // Fetch detailed user profile from database
            let dbUser = null;
            try {
                const userData = await client.graphql({
                    query: getUser,
                    variables: { id: currentUser.userId }
                });
                console.log('User data from database:', userData);
                // @ts-ignore
                dbUser = userData.data.getUser;
            } catch (dbError) {
                console.log('Database query error (will create user):', dbError);
            }

            if (dbUser) {
                console.log('Setting user from database:', dbUser);
                setUser({
                    id: dbUser.id,
                    email: dbUser.email,
                    username: dbUser.username,
                    role: dbUser.role as UserRole
                });
            } else {
                console.log('No DB user found, creating one now...');
                // Create the missing DB user
                const newUser = {
                    id: currentUser.userId,
                    username: attributes.email?.split('@')[0] || currentUser.username,
                    email: attributes.email || '',
                    role: 'athlete' as UserRole
                };

                try {
                    await client.graphql({
                        query: createUser,
                        variables: { input: newUser }
                    });
                    console.log('Created DB user:', newUser);
                } catch (dbError) {
                    console.log('Error creating DB user:', dbError);
                }

                // Set user state with fallback
                setUser(newUser);
            }
        } catch (error) {
            console.log('No user signed in (Cognito error):', error);
            setUser(null);
        } finally {
            setIsLoading(false);
        }
    };

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

    const signIn = async (email: string, pass: string, role?: UserRole): Promise<boolean> => {
        try {
            console.log('Attempting sign in for:', email);
            const { isSignedIn, nextStep } = await amplifySignIn({ username: email, password: pass });
            if (isSignedIn) {
                // Check if user exists in DB, if not create (only if role provided)
                if (role) {
                    // We need to wait for checkUser to populate 'user' state, 
                    // but checkUser is async and sets state. 
                    // Better to manually fetch currentUser ID here to ensure we have it for DB creation
                    try {
                        const currentUser = await getCurrentUser();
                        const userData = await client.graphql({
                            query: getUser,
                            variables: { id: currentUser.userId }
                        });
                        // @ts-ignore
                        if (!userData.data.getUser) {
                            // Create DB User
                            const newUser = {
                                id: currentUser.userId,
                                username: email.split('@')[0],
                                email: email,
                                role: role
                            };
                            await client.graphql({
                                query: createUser,
                                variables: { input: newUser }
                            });
                        }
                    } catch (err) {
                        console.log("Error checking/creating DB user on sign in:", err);
                    }
                }

                await checkUser(); // Refresh user state
                return true;
            }
            console.log("Next step:", nextStep);
            return false;
        } catch (error: any) {
            console.error('Sign in error:', error);
            console.error('Sign in error details:', JSON.stringify(error, null, 2));
            console.error('Error name:', error?.name);
            console.error('Error message:', error?.message);
            console.error('Error stack:', error?.stack);
            if (error?.underlyingError) {
                console.error('Underlying error:', error.underlyingError);
            }
            return false;
        }
    };

    const signUp = async (email: string, pass: string, role: UserRole = 'athlete'): Promise<{ isSignedUp: boolean; nextStep?: string }> => {
        try {
            // 1. Create Auth User in Cognito
            const { isSignUpComplete, userId, nextStep } = await amplifySignUp({
                username: email,
                password: pass,
                options: {
                    userAttributes: {
                        email,
                    }
                }
            });

            if (userId) {
                // DO NOT Create DB User Record here. Wait for verification + sign in.

                if (isSignUpComplete) {
                    // Auto Sign-In (pass role so DB record is created)
                    await signIn(email, pass, role);
                    return { isSignedUp: true };
                } else {
                    // Needs confirmation
                    return { isSignedUp: true, nextStep: nextStep.signUpStep };
                }
            }
            return { isSignedUp: false };
        } catch (error: any) {
            console.error('Sign up error:', error);
            if (error.name === 'UsernameExistsException') {
                // Try to resend code to see if unconfirmed
                try {
                    await resendSignUpCode({ username: email });
                    return { isSignedUp: true, nextStep: 'CONFIRM_SIGN_UP' };
                } catch (resendError) {
                    // Likely already confirmed, try signing in
                    console.log("User exists and likely confirmed, attempting sign in...");
                    const signedIn = await signIn(email, pass, role);
                    return { isSignedUp: signedIn };
                }
            }
            return { isSignedUp: false };
        }
    };

    const confirmUser = async (email: string, code: string): Promise<boolean> => {
        try {
            const { isSignUpComplete } = await confirmSignUp({
                username: email,
                confirmationCode: code
            });
            return isSignUpComplete;
        } catch (error) {
            console.error('Confirmation error:', error);
            return false;
        }
    };

    const [completedWorkouts, setCompletedWorkouts] = useState<string[]>([]);

    const completeWorkout = (id: string) => {
        if (!completedWorkouts.includes(id)) {
            setCompletedWorkouts(prev => [...prev, id]);
        }
    };

    const signOut = async () => {
        try {
            // Attempt AWS Sign Out
            await amplifySignOut();
        } catch (error) {
            // Log but proceed to clear local state
            console.log('Error during AWS sign out (ignoring to force local logout):', error);
        } finally {
            // Always clear local state
            setUser(null);
            setCompletedWorkouts([]);
            router.replace('/auth/sign-in');
        }
    };

    return (
        <AuthContext.Provider value={{ user, isLoading, signIn, signUp, confirmUser, signOut, completedWorkouts, completeWorkout }}>
            {children}
        </AuthContext.Provider>
    );
}
