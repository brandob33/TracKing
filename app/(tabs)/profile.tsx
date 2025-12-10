import { useAuth } from '@/context/AuthContext';
import { listWorkouts } from '@/src/graphql/queries';
import { Ionicons } from '@expo/vector-icons';
import { generateClient } from 'aws-amplify/api';
import React, { useEffect, useState } from 'react';
import { Alert, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

const UCI_BLUE = '#002855';
const UCI_GOLD = '#FDC82F';

export default function ProfileScreen() {
    const { signOut, user } = useAuth();
    const client = generateClient();
    const [stats, setStats] = useState({ total: 0, thisMonth: 0, trainingHours: 0 });

    useEffect(() => {
        if (user?.id) {
            fetchStats();
        }
    }, [user]);

    const fetchStats = async () => {
        try {
            // Fetch workouts for the logged-in user (athleteId filter)
            const workoutData = await client.graphql({
                query: listWorkouts,
                variables: {
                    filter: {
                        athleteId: { eq: user?.id }
                    }
                }
            });

            // @ts-ignore
            const workouts = workoutData.data.listWorkouts.items;

            // Calculate Stats
            const total = workouts.length;

            const now = new Date();
            const currentMonth = now.getMonth();
            const currentYear = now.getFullYear();

            const thisMonth = workouts.filter((w: any) => {
                const wDate = new Date(w.date);
                return wDate.getMonth() === currentMonth && wDate.getFullYear() === currentYear;
            }).length;

            // Mock training hours logic (e.g. 1 hour per workout)
            const trainingHours = total * 1;

            setStats({ total, thisMonth, trainingHours });

        } catch (error) {
            console.error("Error fetching stats:", error);
        }
    };

    const handleSignOut = () => {
        Alert.alert(
            "Sign Out",
            "Are you sure you want to sign out?",
            [
                { text: "Cancel", style: "cancel" },
                { text: "Sign Out", style: "destructive", onPress: () => { signOut(); } }
            ]
        );
    };

    return (
        <SafeAreaView style={styles.container}>
            <ScrollView contentContainerStyle={styles.scrollContent}>

                {/* Profile Header */}
                <View style={styles.profileHeader}>
                    <View style={styles.avatarContainer}>
                        <View style={styles.avatarPlaceholder}>
                            <Ionicons name="person" size={40} color="#fff" />
                        </View>
                        <TouchableOpacity style={styles.editBadge}>
                            <Ionicons name="camera" size={14} color={UCI_BLUE} />
                        </TouchableOpacity>
                    </View>
                    <Text style={styles.userName}>{user?.username || 'User'}</Text>
                    <Text style={styles.userRole}>Sprinter • UCI</Text>
                </View>

                {/* Stats Summary Card */}
                <View style={styles.statsCard}>
                    <View style={styles.statItem}>
                        <Text style={styles.statValue}>{stats.total}</Text>
                        <Text style={styles.statLabel}>Workouts</Text>
                    </View>
                    <View style={styles.statDivider} />
                    <View style={styles.statItem}>
                        <Text style={styles.statValue}>{stats.thisMonth}</Text>
                        <Text style={styles.statLabel}>This Month</Text>
                    </View>
                    <View style={styles.statDivider} />
                    <View style={styles.statItem}>
                        <Text style={styles.statValue}>{stats.trainingHours}h</Text>
                        <Text style={styles.statLabel}>Training</Text>
                    </View>
                </View>


                {/* Settings/Info */}
                <View style={styles.section}>
                    <Text style={styles.sectionHeader}>ACCOUNT INFO</Text>
                    <View style={styles.menuItem}>
                        <Text style={styles.menuLabel}>Email</Text>
                        <Text style={styles.menuValue}>brandon@example.com</Text>
                    </View>
                    <View style={styles.menuItem}>
                        <Text style={styles.menuLabel}>Member Since</Text>
                        <Text style={styles.menuValue}>Dec 2024</Text>
                    </View>
                </View>

                {/* Danger Zone */}
                <TouchableOpacity style={styles.deleteButton} onPress={handleSignOut}>
                    <Ionicons name="log-out-outline" size={20} color="#ff3b30" />
                    <Text style={styles.deleteText}>Sign Out</Text>
                </TouchableOpacity>

            </ScrollView>
        </SafeAreaView>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#000000',
    },
    scrollContent: {
        padding: 20,
        alignItems: 'center',
    },
    profileHeader: {
        alignItems: 'center',
        marginTop: 20,
        marginBottom: 30,
    },
    avatarContainer: {
        position: 'relative',
        marginBottom: 16,
    },
    avatarPlaceholder: {
        width: 100,
        height: 100,
        borderRadius: 50,
        backgroundColor: '#1c1c1e',
        alignItems: 'center',
        justifyContent: 'center',
        borderWidth: 2,
        borderColor: UCI_GOLD,
    },
    editBadge: {
        position: 'absolute',
        bottom: 0,
        right: 0,
        backgroundColor: UCI_GOLD,
        width: 32,
        height: 32,
        borderRadius: 16,
        alignItems: 'center',
        justifyContent: 'center',
        borderWidth: 2,
        borderColor: '#000',
    },
    userName: {
        color: '#fff',
        fontSize: 24,
        fontWeight: 'bold',
    },
    userRole: {
        color: '#8e8e93',
        fontSize: 16,
        marginTop: 4,
    },
    statsCard: {
        flexDirection: 'row',
        backgroundColor: UCI_BLUE,
        borderRadius: 20,
        padding: 20,
        width: '100%',
        justifyContent: 'space-around',
        marginBottom: 30,
    },
    statItem: {
        alignItems: 'center',
    },
    statValue: {
        color: '#fff',
        fontSize: 20,
        fontWeight: 'bold',
    },
    statLabel: {
        color: 'rgba(255,255,255,0.7)',
        fontSize: 12,
        marginTop: 4,
    },
    statDivider: {
        width: 1,
        backgroundColor: 'rgba(255,255,255,0.2)',
    },
    section: {
        width: '100%',
        marginBottom: 30,
    },
    sectionHeader: {
        color: '#8e8e93',
        fontSize: 12,
        fontWeight: '700',
        marginBottom: 10,
        marginLeft: 10,
        textTransform: 'uppercase',
    },
    menuItem: {
        backgroundColor: '#1c1c1e',
        padding: 16,
        flexDirection: 'row',
        justifyContent: 'space-between',
        marginBottom: 1, // Separator look
        borderRadius: 12,
    },
    menuLabel: {
        color: '#fff',
        fontSize: 16,
    },
    menuValue: {
        color: '#8e8e93',
        fontSize: 16,
    },
    deleteButton: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
        padding: 16,
        borderRadius: 12,
        backgroundColor: 'rgba(255, 59, 48, 0.1)',
        width: '100%',
    },
    deleteText: {
        color: '#ff3b30',
        fontSize: 16,
        fontWeight: '600',
    },
});
