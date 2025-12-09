import { useAuth } from '@/context/AuthContext';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import React, { useState } from 'react';
import { ActivityIndicator, Alert, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';

const UCI_BLUE = '#002855';
const UCI_GOLD = '#FDC82F';

export default function SignUp() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [confirmPass, setConfirmPass] = useState('');
    const [loading, setLoading] = useState(false);
    const { signUp } = useAuth();
    const router = useRouter();

    const handleSignUp = async () => {
        if (!email || !password || !confirmPass) {
            Alert.alert('Error', 'Please fill in all fields.');
            return;
        }
        if (password !== confirmPass) {
            Alert.alert('Error', 'Passwords do not match.');
            return;
        }

        setLoading(true);
        // Automatically creates an 'athlete' account for this demo
        const success = await signUp(email, password);
        setLoading(false);

        if (!success) {
            Alert.alert('Error', 'Failed to create account.');
        }
    };

    return (
        <View style={styles.container}>
            <LinearGradient colors={['#000000', UCI_BLUE]} style={styles.background} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1.5 }} />

            <View style={styles.content}>
                <TouchableOpacity style={styles.backBtn} onPress={() => router.back()}>
                    <Ionicons name="arrow-back" size={24} color="#fff" />
                </TouchableOpacity>

                <View style={styles.header}>
                    <Text style={styles.title}>Create Account</Text>
                    <Text style={styles.subtitle}>Join the team</Text>
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

                    <View style={styles.inputContainer}>
                        <Ionicons name="lock-closed" size={20} color="#8e8e93" style={styles.inputIcon} />
                        <TextInput
                            style={styles.input}
                            placeholder="Confirm Password"
                            placeholderTextColor="#8e8e93"
                            secureTextEntry
                            autoCapitalize="none"
                            value={confirmPass}
                            onChangeText={setConfirmPass}
                        />
                    </View>

                    <TouchableOpacity
                        style={styles.signUpBtn}
                        onPress={handleSignUp}
                        disabled={loading}
                    >
                        {loading ? (
                            <ActivityIndicator color="#000" />
                        ) : (
                            <Text style={styles.signUpText}>CREATE ACCOUNT</Text>
                        )}
                    </TouchableOpacity>
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
    },
    content: {
        flex: 1,
        justifyContent: 'center',
        padding: 24,
    },
    backBtn: {
        position: 'absolute',
        top: 60,
        left: 20,
        width: 40,
        height: 40,
        borderRadius: 20,
        backgroundColor: 'rgba(255,255,255,0.1)',
        alignItems: 'center',
        justifyContent: 'center',
    },
    header: {
        marginBottom: 40,
    },
    title: {
        fontSize: 32,
        fontWeight: 'bold',
        color: '#fff',
    },
    subtitle: {
        fontSize: 16,
        color: '#8e8e93',
        marginTop: 8,
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
    signUpBtn: {
        backgroundColor: '#fff',
        height: 56,
        borderRadius: 12,
        alignItems: 'center',
        justifyContent: 'center',
        marginTop: 16,
    },
    signUpText: {
        color: '#000',
        fontSize: 16,
        fontWeight: 'bold',
    },
});
