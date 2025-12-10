import { useAuth } from '@/context/AuthContext';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import React, { useState } from 'react';
import { ActivityIndicator, Alert, Keyboard, KeyboardAvoidingView, Platform, StyleSheet, Text, TextInput, TouchableOpacity, TouchableWithoutFeedback, View } from 'react-native';

const UCI_BLUE = '#002855';
const UCI_GOLD = '#FDC82F';

export default function SignUp() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [confirmPass, setConfirmPass] = useState('');
    const [role, setRole] = useState<'athlete' | 'coach'>('athlete');
    const [loading, setLoading] = useState(false);

    // Verification State
    const [needsVerification, setNeedsVerification] = useState(false);
    const [verificationCode, setVerificationCode] = useState('');

    const { signUp, confirmUser, signIn } = useAuth();
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
        const { isSignedUp, nextStep } = await signUp(email, password, role);
        setLoading(false);

        if (nextStep === 'CONFIRM_SIGN_UP') {
            setNeedsVerification(true);
            Alert.alert('Verification Code Sent', 'Please check your email for a confirmation code.');
        } else if (!isSignedUp) {
            Alert.alert('Error', 'Failed to create account or sign in.');
        }
        // If isSignedUp is true and no nextStep, auto-login handled in context
    };

    const handleVerify = async () => {
        if (!verificationCode) {
            Alert.alert('Error', 'Please enter the verification code.');
            return;
        }
        setLoading(true);
        const success = await confirmUser(email, verificationCode);
        if (success) {
            // Verification successful, proceed to sign in
            const signedIn = await signIn(email, password, role);
            if (!signedIn) {
                Alert.alert('Success', 'Account verified! Please sign in.');
                // If auto-login fails, go back to sign in
                router.back();
            } else {
                // Auto-login success, AuthContext will redirect
            }
        } else {
            Alert.alert('Error', 'Invalid verification code.');
            setLoading(false);
        }
    };

    const dismissKeyboard = () => {
        Keyboard.dismiss();
    };

    return (
        <View style={styles.container}>
            <LinearGradient colors={['#000000', UCI_BLUE]} style={styles.background} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1.5 }} />

            <KeyboardAvoidingView
                behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
                style={{ flex: 1 }}
            >
                <TouchableWithoutFeedback onPress={dismissKeyboard}>
                    <View style={styles.content}>
                        <TouchableOpacity style={styles.backBtn} onPress={() => router.back()}>
                            <Ionicons name="arrow-back" size={24} color="#fff" />
                        </TouchableOpacity>

                        <View style={styles.header}>
                            <Text style={styles.title}>{needsVerification ? 'Verify Account' : 'Create Account'}</Text>
                            <Text style={styles.subtitle}>{needsVerification ? 'Enter the code sent to your email' : 'Join the team'}</Text>
                        </View>

                        {needsVerification ? (
                            // Verification Form
                            <View style={styles.form}>
                                <View style={styles.inputContainer}>
                                    <Ionicons name="key-outline" size={20} color="#8e8e93" style={styles.inputIcon} />
                                    <TextInput
                                        style={styles.input}
                                        placeholder="Verification Code"
                                        placeholderTextColor="#8e8e93"
                                        keyboardType="number-pad"
                                        returnKeyType="done"
                                        onSubmitEditing={handleVerify}
                                        value={verificationCode}
                                        onChangeText={setVerificationCode}
                                    />
                                </View>

                                <TouchableOpacity
                                    style={styles.signUpBtn}
                                    onPress={handleVerify}
                                    disabled={loading}
                                >
                                    {loading ? (
                                        <ActivityIndicator color="#000" />
                                    ) : (
                                        <Text style={styles.signUpText}>VERIFY & SIGN IN</Text>
                                    )}
                                </TouchableOpacity>
                            </View>
                        ) : (
                            // Sign Up Form
                            <View style={styles.form}>
                                {/* Role Selector */}
                                <View style={styles.roleContainer}>
                                    <TouchableOpacity
                                        style={[styles.roleBtn, role === 'athlete' && styles.roleBtnActive]}
                                        onPress={() => setRole('athlete')}
                                    >
                                        <Ionicons name="person" size={20} color={role === 'athlete' ? '#000' : '#8e8e93'} />
                                        <Text style={[styles.roleText, role === 'athlete' && styles.roleTextActive]}>Athlete</Text>
                                    </TouchableOpacity>
                                    <TouchableOpacity
                                        style={[styles.roleBtn, role === 'coach' && styles.roleBtnActive]}
                                        onPress={() => setRole('coach')}
                                    >
                                        <Ionicons name="stopwatch" size={20} color={role === 'coach' ? '#000' : '#8e8e93'} />
                                        <Text style={[styles.roleText, role === 'coach' && styles.roleTextActive]}>Coach</Text>
                                    </TouchableOpacity>
                                </View>

                                <View style={styles.inputContainer}>
                                    <Ionicons name="mail" size={20} color="#8e8e93" style={styles.inputIcon} />
                                    <TextInput
                                        style={styles.input}
                                        placeholder="Email"
                                        placeholderTextColor="#8e8e93"
                                        autoCapitalize="none"
                                        keyboardType="email-address"
                                        returnKeyType="next"
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
                        )}
                    </View>
                </TouchableWithoutFeedback>
            </KeyboardAvoidingView>
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
    roleContainer: {
        flexDirection: 'row',
        gap: 12,
        marginBottom: 8,
    },
    roleBtn: {
        flex: 1,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: 'rgba(28, 28, 30, 0.8)',
        paddingVertical: 14,
        borderRadius: 12,
        borderWidth: 1,
        borderColor: '#2c2c2e',
        gap: 8,
    },
    roleBtnActive: {
        backgroundColor: '#fff',
        borderColor: '#fff',
    },
    roleText: {
        color: '#8e8e93',
        fontWeight: '600',
        fontSize: 16,
    },
    roleTextActive: {
        color: '#000',
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


