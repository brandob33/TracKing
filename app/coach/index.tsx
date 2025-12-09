import { useAuth } from '@/context/AuthContext';
import { Ionicons } from '@expo/vector-icons';
import React from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

const UCI_BLUE = '#002855';
const UCI_GOLD = '#FDC82F';

export default function CoachDashboard() {
    const { signOut } = useAuth();

    return (
        <SafeAreaView style={styles.container}>
            <View style={styles.header}>
                <Text style={styles.title}>Coach Dashboard</Text>
                <TouchableOpacity onPress={signOut} style={styles.signOutBtn}>
                    <Ionicons name="log-out-outline" size={24} color="#fff" />
                </TouchableOpacity>
            </View>

            <View style={styles.content}>
                <Ionicons name="construct" size={80} color={UCI_GOLD} />
                <Text style={styles.message}>Admin Interface Under Construction</Text>
                <Text style={styles.subMessage}>Group Management & Athlete Assignments Coming Soon</Text>
            </View>
        </SafeAreaView>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#002855', // Blue background for coach
    },
    header: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        padding: 20,
    },
    title: {
        fontSize: 24,
        fontWeight: 'bold',
        color: '#fff',
    },
    signOutBtn: {
        padding: 8,
    },
    content: {
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
        padding: 20,
    },
    message: {
        color: '#fff',
        fontSize: 22,
        fontWeight: 'bold',
        marginTop: 20,
        textAlign: 'center',
    },
    subMessage: {
        color: '#bbb',
        fontSize: 16,
        marginTop: 10,
        textAlign: 'center',
    },
});
