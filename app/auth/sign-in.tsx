import { useAuth } from '@/context/AuthContext';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { Link, useRouter } from 'expo-router';
import React, { useState } from 'react';
import { ActivityIndicator, Alert, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';

const UCI_BLUE = '#002855';
const UCI_GOLD = '#FDC82F';

export default function SignIn() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [loading, setLoading] = useState(false);
    const { signIn } = useAuth();
    const router = useRouter();

    const handleSignIn = async () => {
        if (!email || !password) {
            Alert.alert('Error', 'Please enter both email and password.');
            return;
        }

        setLoading(true);
        const success = await signIn(email, password);
        setLoading(false);

        if (!success) {
            Alert.alert('Login Failed', 'Invalid credentials. Try athlete/athlete123');
        }
        // Navigation is handled by the AuthContext effect
    };

    return (
        <View style={styles.container}>
            <LinearGradient colors={[UCI_BLUE, '#000000']} style={styles.background} />

            <View style={styles.content}>
                <View style={styles.header}>
                    <Ionicons name="stopwatch" size={64} color={UCI_GOLD} />
                    <Text style={styles.title}>TracKing</Text>
                    <Text style={styles.subtitle}>Track & Field Performance</Text>
                </View>

                <View style={styles.form}>
                    <View style={styles.inputContainer}>
                        <Ionicons name="mail" size={20} color="#8e8e93" style={styles.inputIcon} />
                        <TextInput
                            style={styles.input}
                            placeholder="Email"
                            placeholderTextColor="#8e8e93"
                            autoCapitalize="none"
                            value={email}
                            onChangeText={setEmail}
                        />
                    </View>

                    <View style={styles.inputContainer}>
                        <Ionicons name="lock-closed" size={20} color="#8e8e93" style={styles.inputIcon} />
                        <TextInput
                            style={styles.input}
                            placeholder="Password"
                            placeholderTextColor="#8e8e93"
                            secureTextEntry
                            autoCapitalize="none"
                            value={password}
                            onChangeText={setPassword}
                        />
                    </View>

                    <TouchableOpacity
                        style={styles.signInBtn}
                        onPress={handleSignIn}
                        disabled={loading}
                    >
                        {loading ? (
                            <ActivityIndicator color={UCI_BLUE} />
                        ) : (
                            <Text style={styles.signInText}>SIGN IN</Text>
                        )}
                    </TouchableOpacity>

                    <Text style={styles.orText}>OR</Text>

                    <TouchableOpacity style={styles.googleBtn} onPress={() => Alert.alert("Coming Soon", "Google Sign In implementation pending")}>
                        <Ionicons name="logo-google" size={20} color="#fff" />
                        <Text style={styles.googleText}>Sign in with Google</Text>
                    </TouchableOpacity>
                </View>

                <View style={styles.footer}>
                    <Text style={styles.footerText}>Don't have an account? </Text>
                    <Link href="/auth/sign-up" asChild>
                        <TouchableOpacity>
                            <Text style={styles.linkText}>Sign Up</Text>
                        </TouchableOpacity>
                    </Link>
                </View>
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#000000',
    },
    background: {
        ...StyleSheet.absoluteFillObject,
        opacity: 0.8,
    },
    content: {
        flex: 1,
        justifyContent: 'center',
        padding: 24,
    },
    header: {
        alignItems: 'center',
        marginBottom: 48,
    },
    title: {
        fontSize: 42,
        fontWeight: '900',
        color: '#fff',
        marginTop: 16,
        letterSpacing: 2,
    },
    subtitle: {
        fontSize: 16,
        color: UCI_GOLD,
        marginTop: 8,
        letterSpacing: 1,
    },
    form: {
        gap: 16,
    },
    inputContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        backgroundColor: 'rgba(28, 28, 30, 0.8)',
        borderRadius: 12,
        paddingHorizontal: 16,
        height: 56,
        borderWidth: 1,
        borderColor: '#2c2c2e',
    },
    inputIcon: {
        marginRight: 12,
    },
    input: {
        flex: 1,
        color: '#fff',
        fontSize: 16,
    },
    signInBtn: {
        backgroundColor: UCI_GOLD,
        height: 56,
        borderRadius: 12,
        alignItems: 'center',
        justifyContent: 'center',
        marginTop: 8,
        elevation: 4,
    },
    signInText: {
        color: UCI_BLUE,
        fontSize: 16,
        fontWeight: 'bold',
        letterSpacing: 0.5,
    },
    orText: {
        color: '#8e8e93',
        textAlign: 'center',
        fontSize: 14,
        marginVertical: 8,
    },
    googleBtn: {
        flexDirection: 'row',
        backgroundColor: '#333',
        height: 56,
        borderRadius: 12,
        alignItems: 'center',
        justifyContent: 'center',
        gap: 12,
    },
    googleText: {
        color: '#fff',
        fontSize: 16,
        fontWeight: '600',
    },
    footer: {
        flexDirection: 'row',
        justifyContent: 'center',
        marginTop: 32,
    },
    footerText: {
        color: '#8e8e93',
        fontSize: 15,
    },
    linkText: {
        color: UCI_GOLD,
        fontSize: 15,
        fontWeight: 'bold',
    },
});
