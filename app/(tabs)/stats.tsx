import { Ionicons } from '@expo/vector-icons';
import { Link } from 'expo-router';
import React from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

const UCI_BLUE = '#002855';
const UCI_GOLD = '#FDC82F';

const HISTORY = [
    {
        id: '1',
        date: 'Dec 07',
        title: 'Block Starts',
        times: ['4.21', '4.18', '4.25']
    },
    {
        id: '2',
        date: 'Dec 05',
        title: 'Flying 30s',
        times: ['2.95', '2.92', '2.88']
    },
    {
        id: '3',
        date: 'Dec 03',
        title: 'Speed Endurance',
        times: ['17.5', '17.8', '18.1']
    },
];

export default function StatsScreen() {
    return (
        <SafeAreaView style={styles.container}>
            <View style={styles.header}>
                <Text style={styles.title}>Performance History</Text>
            </View>

            <ScrollView contentContainerStyle={styles.scrollContent}>
                {HISTORY.map((item) => (
                    <Link
                        key={item.id}
                        href={{
                            pathname: '/workout',
                            params: {
                                day: item.date,
                                title: item.title,
                                // Pass times as a simple comma-separated string for easy parsing
                                initialData: item.times.join(',')
                            }
                        }}
                        asChild
                    >
                        <TouchableOpacity activeOpacity={0.8} style={styles.card}>
                            <View style={styles.cardHeader}>
                                <View>
                                    <Text style={styles.date}>{item.date}</Text>
                                    <Text style={styles.cardTitle}>{item.title}</Text>
                                </View>
                                <Ionicons name="create-outline" size={24} color={UCI_GOLD} />
                            </View>

                            <View style={styles.divider} />

                            <View style={styles.statsRow}>
                                <Text style={styles.statsLabel}>Logged Times:</Text>
                                <View style={styles.tags}>
                                    {item.times.map((t, i) => (
                                        <View key={i} style={styles.tag}>
                                            <Text style={styles.tagText}>{t}s</Text>
                                        </View>
                                    ))}
                                </View>
                            </View>
                        </TouchableOpacity>
                    </Link>
                ))}

                <View style={styles.emptyState}>
                    <Text style={styles.emptyText}>Tap a workout to view details or edit.</Text>
                </View>
            </ScrollView>
        </SafeAreaView>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#000000',
    },
    header: {
        padding: 20,
        borderBottomWidth: 1,
        borderBottomColor: '#1c1c1e',
    },
    title: {
        fontSize: 24,
        fontWeight: 'bold',
        color: '#fff',
        textTransform: 'uppercase',
    },
    scrollContent: {
        padding: 20,
    },
    card: {
        backgroundColor: '#1c1c1e',
        borderRadius: 16,
        padding: 20,
        marginBottom: 16,
    },
    cardHeader: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'flex-start',
        marginBottom: 16,
    },
    date: {
        color: UCI_GOLD,
        fontSize: 14,
        fontWeight: '600',
        marginBottom: 4,
    },
    cardTitle: {
        color: '#fff',
        fontSize: 18,
        fontWeight: 'bold',
    },
    divider: {
        height: 1,
        backgroundColor: '#2c2c2e',
        marginBottom: 16,
    },
    statsRow: {
        flexDirection: 'row',
        alignItems: 'center',
        flexWrap: 'wrap',
        gap: 12,
    },
    statsLabel: {
        color: '#8e8e93',
        fontSize: 14,
    },
    tags: {
        flexDirection: 'row',
        gap: 8,
    },
    tag: {
        backgroundColor: 'rgba(0, 40, 85, 0.6)', // UCI Blue transparent
        paddingHorizontal: 8,
        paddingVertical: 4,
        borderRadius: 6,
        borderWidth: 1,
        borderColor: UCI_BLUE,
    },
    tagText: {
        color: '#fff',
        fontSize: 13,
        fontWeight: '600',
        fontVariant: ['tabular-nums'],
    },
    emptyState: {
        marginTop: 20,
        alignItems: 'center',
    },
    emptyText: {
        color: '#555',
        fontStyle: 'italic',
    },
});
