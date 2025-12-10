import { useAuth } from '@/context/AuthContext';
import { Ionicons } from '@expo/vector-icons';
import { generateClient } from 'aws-amplify/api';
import { Link } from 'expo-router';
import React, { useCallback, useEffect, useState } from 'react';
import { Alert, RefreshControl, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

const UCI_BLUE = '#002855';
const UCI_GOLD = '#FDC82F';

// Custom Query to fetch workouts with nested exercises
const listWorkoutsWithExercises = /* GraphQL */ `
  query ListWorkouts($filter: ModelWorkoutFilterInput) {
    listWorkouts(filter: $filter) {
      items {
        id
        title
        date
        status
        exercises {
            items {
                id
                sets {
                    distance
                }
            }
        }
      }
    }
  }
`;

export default function StatsScreen() {
    const { user, completedWorkouts } = useAuth(); // Depend on user and completedWorkouts
    const client = generateClient();
    const [localHistory, setLocalHistory] = useState<any[]>([]);
    const [isSelectionMode, setIsSelectionMode] = useState(false);
    const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
    const [refreshing, setRefreshing] = useState(false);

    const fetchWorkouts = useCallback(async () => {
        if (!user) return;
        try {
            const result = await client.graphql({
                query: listWorkoutsWithExercises,
                variables: {
                    filter: { athleteId: { eq: user.id } }
                }
            });

            // @ts-ignore
            const items = result.data.listWorkouts.items;

            // Transform data for UI
            const formattedHistory = items.map((w: any) => {
                // Flatten sets from all exercises (assuming simplistic 'distance' holds the time)
                const allTimes: string[] = [];
                // @ts-ignore
                if (w.exercises && w.exercises.items) {
                    // @ts-ignore
                    w.exercises.items.forEach((ex: any) => {
                        // @ts-ignore
                        if (ex.sets) {
                            // @ts-ignore
                            ex.sets.forEach((s: any) => {
                                if (s.distance) {
                                    allTimes.push(s.distance.toString());
                                }
                            });
                        }
                    });
                }

                return {
                    id: w.id,
                    date: new Date(w.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
                    title: w.title,
                    times: allTimes,
                    fullDate: w.date // Keep full ISO date for sorting if needed
                };
            });

            // Sort by date descending
            formattedHistory.sort((a: any, b: any) => new Date(b.fullDate).getTime() - new Date(a.fullDate).getTime());

            setLocalHistory(formattedHistory);
        } catch (error) {
            console.error("Error fetching workouts:", error);
        }
    }, [user]);

    useEffect(() => {
        fetchWorkouts();
    }, [fetchWorkouts, completedWorkouts]); // Refetch when completedWorkouts changes (trigger from workout.tsx)

    const onRefresh = useCallback(async () => {
        setRefreshing(true);
        await fetchWorkouts();
        setRefreshing(false);
    }, [fetchWorkouts]);

    const toggleSelection = (id: string) => {
        const newSet = new Set(selectedIds);
        if (newSet.has(id)) {
            newSet.delete(id);
        } else {
            newSet.add(id);
        }
        setSelectedIds(newSet);
    };

    const handleDelete = () => {
        Alert.alert(
            "Delete Workouts",
            `Are you sure you want to delete ${selectedIds.size} workouts?`,
            [
                { text: "Cancel", style: "cancel" },
                {
                    text: "Delete",
                    style: "destructive",
                    onPress: () => {
                        setLocalHistory(prev => prev.filter(item => !selectedIds.has(item.id)));
                        setSelectedIds(new Set());
                        setIsSelectionMode(false);
                    }
                }
            ]
        );
    };

    const renderCard = (item: any) => {
        const isSelected = selectedIds.has(item.id);

        const cardContent = (
            <View style={[styles.card, isSelected && styles.cardSelected]}>
                <View style={styles.cardHeader}>
                    <View>
                        <Text style={styles.date}>{item.date}</Text>
                        <Text style={styles.cardTitle}>{item.title}</Text>
                    </View>
                    {isSelectionMode ? (
                        <Ionicons
                            name={isSelected ? "checkbox" : "square-outline"}
                            size={24}
                            color={isSelected ? UCI_GOLD : "#555"}
                        />
                    ) : (
                        <Ionicons name="create-outline" size={24} color={UCI_GOLD} />
                    )}
                </View>

                <View style={styles.divider} />

                <View style={styles.statsRow}>
                    <Text style={styles.statsLabel}>Logged Times:</Text>
                    <View style={styles.tags}>
                        {item.times.map((t: string, i: number) => (
                            <View key={i} style={styles.tag}>
                                <Text style={styles.tagText}>{t}s</Text>
                            </View>
                        ))}
                    </View>
                </View>
            </View>
        );

        if (isSelectionMode) {
            return (
                <TouchableOpacity key={item.id} activeOpacity={0.8} onPress={() => toggleSelection(item.id)}>
                    {cardContent}
                </TouchableOpacity>
            );
        }

        return (
            <Link
                key={item.id}
                href={{
                    pathname: '/workout',
                    params: {
                        day: item.date,
                        title: item.title,
                        initialData: item.times.join(',')
                    }
                }}
                asChild
            >
                <TouchableOpacity activeOpacity={0.8}>
                    {cardContent}
                </TouchableOpacity>
            </Link>
        );
    };

    return (
        <SafeAreaView style={styles.container}>
            <View style={styles.header}>
                <Text style={styles.title}>Performance</Text>
                <TouchableOpacity onPress={() => {
                    setIsSelectionMode(!isSelectionMode);
                    setSelectedIds(new Set());
                }}>
                    <Text style={styles.headerBtn}>{isSelectionMode ? "Cancel" : "Select"}</Text>
                </TouchableOpacity>
            </View>

            <ScrollView
                contentContainerStyle={styles.scrollContent}
                refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={UCI_GOLD} />}
            >
                {localHistory.map(renderCard)}

                {localHistory.length === 0 && (
                    <View style={styles.emptyState}>
                        <Text style={styles.emptyText}>No workouts logged.</Text>
                    </View>
                )}
            </ScrollView>

            {isSelectionMode && selectedIds.size > 0 && (
                <View style={styles.footerAction}>
                    <TouchableOpacity style={styles.deleteBtn} onPress={handleDelete}>
                        <Text style={styles.deleteBtnText}>Delete ({selectedIds.size})</Text>
                        <Ionicons name="trash-outline" size={20} color="#fff" />
                    </TouchableOpacity>
                </View>
            )}
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
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
    },
    title: {
        fontSize: 24,
        fontWeight: 'bold',
        color: '#fff',
        textTransform: 'uppercase',
    },
    headerBtn: {
        color: UCI_GOLD,
        fontSize: 16,
        fontWeight: '600',
    },
    scrollContent: {
        padding: 20,
        paddingBottom: 100, // Space for delete button
    },
    card: {
        backgroundColor: '#1c1c1e',
        borderRadius: 16,
        padding: 20,
        marginBottom: 16,
        borderWidth: 1,
        borderColor: 'transparent',
    },
    cardSelected: {
        borderColor: UCI_GOLD,
        backgroundColor: '#2c2c2e',
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
    footerAction: {
        position: 'absolute',
        bottom: 20,
        left: 20,
        right: 20,
        alignItems: 'center',
    },
    deleteBtn: {
        backgroundColor: '#ff3b30',
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: 12,
        paddingHorizontal: 24,
        borderRadius: 30,
        gap: 8,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.3,
        shadowRadius: 4,
        elevation: 6,
    },
    deleteBtnText: {
        color: '#fff',
        fontWeight: 'bold',
        fontSize: 16,
    }
});
