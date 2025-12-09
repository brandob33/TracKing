import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';
import WorkoutTimer from '../components/WorkoutTimer';

const UCI_BLUE = '#002855';
const UCI_GOLD = '#FDC82F';

export default function WorkoutScreen() {
    const params = useLocalSearchParams();
    const router = useRouter();

    const dayName = typeof params.day === 'string' ? params.day : 'Today';
    const workoutTitle = typeof params.title === 'string' ? params.title : 'Speed & Power';
    const initialDataStr = typeof params.initialData === 'string' ? params.initialData : '';

    // State to track inputs
    const [inputs, setInputs] = useState<Record<string, string>>({});

    // Initialize data if present
    useEffect(() => {
        if (initialDataStr) {
            const times = initialDataStr.split(',');
            const newInputs: Record<string, string> = {};
            times.forEach((t, index) => {
                // Map index 0 to rep-1, index 1 to rep-2, etc. (1-based rep ID)
                newInputs[`rep-${index + 1}`] = t;
            });
            setInputs(newInputs);
        }
    }, [initialDataStr]);

    const handleInputChange = (id: string, text: string) => {
        setInputs(prev => ({ ...prev, [id]: text }));
    };

    const handleSave = () => {
        Alert.alert("Success", "Workout updated successfully!", [
            { text: "OK", onPress: () => router.back() }
        ]);
    };

    return (
        <View style={styles.container}>
            <Stack.Screen options={{
                title: initialDataStr ? `${dayName}` : `${dayName}'s Workout`,
                headerStyle: { backgroundColor: UCI_BLUE },
                headerTintColor: UCI_GOLD,
                headerTitleStyle: { fontWeight: 'bold' },
            }} />

            <KeyboardAvoidingView
                behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
                style={{ flex: 1 }}
            >
                <ScrollView contentContainerStyle={styles.scrollContent}>
                    {/* Workout Header */}
                    <View style={styles.summaryCard}>
                        <Text style={styles.workoutName}>{workoutTitle}</Text>
                        <Text style={styles.workoutFocus}>
                            {initialDataStr ? 'Reviewing Past Performance' : 'Focus: Max Velocity'}
                        </Text>
                    </View>

                    {/* Warm Up */}
                    <View style={styles.section}>
                        <Text style={styles.sectionTitle}>WARM UP</Text>
                        <View style={styles.listContainer}>
                            <View style={styles.simpleRow}><Text style={styles.rowText}>• Jog 800m</Text></View>
                            <View style={styles.simpleRow}><Text style={styles.rowText}>• Dynamic Studies (2x30m)</Text></View>
                            <View style={styles.simpleRow}><Text style={styles.rowText}>• Build-Ups (4x60m)</Text></View>
                        </View>
                    </View>

                    {/* Main Set - Editable */}
                    <View style={styles.section}>
                        <Text style={styles.sectionTitle}>MAIN SET</Text>

                        <View style={styles.tableHeader}>
                            <Text style={[styles.col, styles.colRep]}>REP</Text>
                            <Text style={[styles.col, styles.colTarget]}>TARGET</Text>
                            <Text style={[styles.col, styles.colRest]}>REST</Text>
                            <Text style={[styles.col, styles.colInput]}>ACTUAL</Text>
                        </View>

                        {[1, 2, 3, 4].map((rep) => (
                            <View key={`rep-${rep}`} style={styles.tableRow}>
                                <Text style={[styles.col, styles.colRep]}>{rep}</Text>
                                <Text style={[styles.col, styles.colTarget]}>4.20s</Text>
                                <Text style={[styles.col, styles.colRest]}>3'</Text>
                                <View style={[styles.col, styles.colInput]}>
                                    <TextInput
                                        style={styles.input}
                                        placeholder="--"
                                        placeholderTextColor="#555"
                                        keyboardType="numeric"
                                        value={inputs[`rep-${rep}`]}
                                        onChangeText={(t) => handleInputChange(`rep-${rep}`, t)}
                                    />
                                </View>
                            </View>
                        ))}
                    </View>

                    {/* Cooldown */}
                    <View style={styles.section}>
                        <Text style={styles.sectionTitle}>COOL DOWN</Text>
                        <View style={styles.listContainer}>
                            <View style={styles.simpleRow}>
                                <Ionicons name="walk-outline" size={18} color="#aaa" />
                                <Text style={styles.rowText}>A Walking Drills</Text>
                            </View>
                            <View style={styles.simpleRow}>
                                <Ionicons name="walk-outline" size={18} color="#aaa" />
                                <Text style={styles.rowText}>B Walking Drills</Text>
                            </View>
                        </View>
                    </View>

                    {/* Supplementals */}
                    <View style={styles.section}>
                        <Text style={styles.sectionTitle}>SUPPLEMENTALS & RECOVERY</Text>
                        <View style={styles.listContainer}>
                            <View style={styles.suppRow}>
                                <View style={styles.suppIcon}><Ionicons name="snow" size={20} color={UCI_BLUE} /></View>
                                <Text style={styles.rowText}>Ice Bath (10 min)</Text>
                            </View>
                            <View style={styles.suppRow}>
                                <View style={styles.suppIcon}><Ionicons name="body" size={20} color={UCI_BLUE} /></View>
                                <Text style={styles.rowText}>Foam Roll / Smash</Text>
                            </View>
                        </View>
                    </View>

                    {/* Complete/Update Button */}
                    <TouchableOpacity style={styles.completeBtn} activeOpacity={0.8} onPress={handleSave}>
                        <LinearGradient
                            colors={[UCI_GOLD, '#e5b000']}
                            style={styles.gradientBtn}
                        >
                            <Text style={styles.completeBtnText}>
                                {initialDataStr ? 'UPDATE WORKOUT' : 'COMPLETE WORKOUT'}
                            </Text>
                            <Ionicons name="checkmark-circle" size={24} color={UCI_BLUE} />
                        </LinearGradient>
                    </TouchableOpacity>

                </ScrollView>
            </KeyboardAvoidingView>

            {/* Timer Fixed at Bottom */}
            <WorkoutTimer />
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#000000',
    },
    scrollContent: {
        padding: 20,
        paddingBottom: 20,
    },
    summaryCard: {
        marginBottom: 24,
    },
    workoutName: {
        color: '#fff',
        fontSize: 28,
        fontWeight: '800',
        fontStyle: 'italic',
    },
    workoutFocus: {
        color: UCI_GOLD,
        fontSize: 16,
        fontWeight: '600',
        marginTop: 4,
    },
    section: {
        marginBottom: 28,
    },
    sectionTitle: {
        color: '#8e8e93',
        fontSize: 13,
        fontWeight: '700',
        letterSpacing: 1.5,
        marginBottom: 10,
        borderBottomWidth: 1,
        borderBottomColor: '#2c2c2e',
        paddingBottom: 6,
    },
    listContainer: {
        backgroundColor: '#1c1c1e',
        borderRadius: 12,
        padding: 16,
    },
    simpleRow: {
        flexDirection: 'row',
        alignItems: 'center',
        marginBottom: 8,
        gap: 10,
    },
    rowText: {
        color: '#fff',
        fontSize: 16,
    },

    // Table Styles
    tableHeader: {
        flexDirection: 'row',
        paddingHorizontal: 12,
        marginBottom: 8,
    },
    tableRow: {
        flexDirection: 'row',
        backgroundColor: '#1c1c1e',
        paddingVertical: 12,
        paddingHorizontal: 12,
        borderRadius: 10,
        marginBottom: 8,
        alignItems: 'center',
    },
    col: {
        color: '#fff',
        textAlign: 'center',
    },
    colRep: { flex: 0.5, fontWeight: 'bold', color: UCI_GOLD },
    colTarget: { flex: 1, color: '#aaa' },
    colRest: { flex: 1, color: '#aaa' },
    colInput: { flex: 1.2 },

    input: {
        backgroundColor: '#333',
        color: '#fff',
        borderRadius: 6,
        textAlign: 'center',
        paddingVertical: 4,
        fontSize: 16,
        borderWidth: 1,
        borderColor: '#444',
    },

    // Supps
    suppRow: {
        flexDirection: 'row',
        alignItems: 'center',
        marginBottom: 12,
        gap: 12,
    },
    suppIcon: {
        backgroundColor: UCI_GOLD,
        padding: 6,
        borderRadius: 8,
    },

    // Complete Button
    completeBtn: {
        marginTop: 10,
        marginBottom: 40,
    },
    gradientBtn: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        paddingVertical: 16,
        borderRadius: 30,
        gap: 10,
    },
    completeBtnText: {
        color: UCI_BLUE,
        fontWeight: '900',
        fontSize: 16,
        letterSpacing: 0.5,
    },
});
