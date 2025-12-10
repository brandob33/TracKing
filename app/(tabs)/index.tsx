import { useAuth } from '@/context/AuthContext';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { Link } from 'expo-router';
import React, { useState } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

// UCI Colors
const UCI_BLUE = '#002855';
const UCI_GOLD = '#FDC82F';

// Mock Data for Workouts
const SCHEDULE: Record<string, { title: string; focus: string; duration: string }> = {
	'Mon': { title: 'Speed & Power', focus: 'Block Starts & Flying 30s', duration: '90m' },
	'Tue': { title: 'Tempo Endurance', focus: '200m Repeats', duration: '75m' },
	'Wed': { title: 'Recovery', focus: 'Circuit & Mobility', duration: '45m' },
	'Thu': { title: 'Speed Endurance', focus: '150m Flys (Sub-max)', duration: '80m' },
	'Fri': { title: 'Pre-Meet Shakeout', focus: 'Blocks & Reaction', duration: '40m' },
	'Sat': { title: 'Meet Day / Rest', focus: 'Competition', duration: '3h' },
	'Sun': { title: 'Active Recovery', focus: 'Long Walk / Yoga', duration: '60m' },
};

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export default function MainMenu() {
	const { user, completedWorkouts } = useAuth();
	const [selectedDate, setSelectedDate] = useState<number>(new Date().getDay());

	const today = new Date();
	const currentDayName = DAYS[selectedDate];

	const workout = SCHEDULE[currentDayName] || SCHEDULE['Mon']; // Fallback
	const isCompleted = completedWorkouts.includes(currentDayName);

	// Generate Week Dates (Static for demo relative to current selected index as pseudo-mock)
	// Real app would use actual date logic. Here we just map 0-6 to the week days.
	const weekDates = DAYS.map((d, index) => {
		// Just for visual flair, let's say Sun is day 10, Mon 11, etc.
		return { day: d, date: 10 + index, index };
	});

	return (
		<SafeAreaView style={styles.container}>
			<ScrollView contentContainerStyle={styles.scrollContent}>
				<View style={styles.header}>
					<Text style={styles.greeting}>Hi {user?.username || 'Athlete'}</Text>
					<Text style={styles.date}>UCI Anteaters</Text>
				</View>

				{/* Horizontal Calendar Strip */}
				<View style={styles.calendarContainer}>
					{weekDates.map((item) => {
						const isSelected = selectedDate === item.index;
						return (
							<TouchableOpacity
								key={item.day}
								style={[styles.dayItem, isSelected && styles.dayItemActive]}
								onPress={() => setSelectedDate(item.index)}
							>
								<Text style={[styles.dayName, isSelected && styles.dayNameActive]}>{item.day}</Text>
								<Text style={[styles.dayNumber, isSelected && styles.dayNumberActive]}>{item.date}</Text>
							</TouchableOpacity>
						);
					})}
				</View>

				<Text style={styles.sectionHeader}>SCHEDULED WORKOUT</Text>

				{/* Dynamic Workout Card */}
				<Link href={{ pathname: '/workout', params: { day: currentDayName } }} asChild>
					<TouchableOpacity activeOpacity={0.9} style={styles.mainCardContainer}>
						<LinearGradient
							colors={[UCI_BLUE, '#1b3d6d']}
							style={styles.mainCard}
							start={{ x: 0, y: 0 }}
							end={{ x: 1, y: 1 }}
						>
							<View style={styles.cardHeaderRow}>
								<View style={styles.badge}>
									<Text style={styles.badgeText}>TODAY</Text>
								</View>
								<Ionicons name="stats-chart" size={24} color={UCI_GOLD} />
							</View>

							<Text style={styles.mainCardTitle}>{workout.title}</Text>
							<Text style={styles.mainCardSubtitle}>{workout.focus}</Text>

							<View style={styles.cardFooter}>
								<View style={styles.metaRow}>
									<Ionicons name="time-outline" size={16} color="#ccc" />
									<Text style={styles.metaText}>{workout.duration}</Text>
								</View>

								{isCompleted ? (
									<View style={[styles.startBtn, { backgroundColor: '#4BB543' }]}>
										<Text style={styles.startBtnText}>COMPLETED</Text>
										<Ionicons name="checkmark-circle" size={16} color="#fff" />
									</View>
								) : (
									<View style={styles.startBtn}>
										<Text style={styles.startBtnText}>START</Text>
										<Ionicons name="arrow-forward" size={16} color={UCI_BLUE} />
									</View>
								)}
							</View>
						</LinearGradient>
					</TouchableOpacity>
				</Link>

				<Text style={styles.sectionHeader}>SUPPLEMENTALS</Text>
				<View style={styles.supplementsContainer}>
					<View style={styles.supplementCard}>
						<Ionicons name="snow" size={24} color={UCI_BLUE} />
						<Text style={styles.supplementTitle}>Ice Bath</Text>
						<Text style={styles.supplementTime}>10 min</Text>
					</View>

					<View style={styles.supplementCard}>
						<Ionicons name="moon" size={24} color={UCI_BLUE} />
						<Text style={styles.supplementTitle}>Quality Sleep</Text>
						<Text style={styles.supplementTime}>8 hrs</Text>
					</View>

					<View style={styles.supplementCard}>
						<Ionicons name="nutrition" size={24} color={UCI_BLUE} />
						<Text style={styles.supplementTitle}>Protein</Text>
						<Text style={styles.supplementTime}>30g</Text>
					</View>
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
	scrollContent: {
		padding: 20,
	},
	header: {
		marginBottom: 20,
		marginTop: 10,
	},
	greeting: {
		fontSize: 28,
		fontWeight: '800',
		color: '#ffffff',
		textTransform: 'uppercase',
	},
	date: {
		fontSize: 16,
		color: UCI_GOLD,
		fontWeight: '600',
		marginTop: 4,
		textTransform: 'uppercase',
		letterSpacing: 1,
	},
	calendarContainer: {
		flexDirection: 'row',
		justifyContent: 'space-between',
		marginBottom: 30,
		backgroundColor: '#1c1c1e',
		padding: 12,
		borderRadius: 16,
	},
	dayItem: {
		alignItems: 'center',
		paddingVertical: 8,
		paddingHorizontal: 10,
		borderRadius: 12,
	},
	dayItemActive: {
		backgroundColor: UCI_BLUE,
	},
	dayName: {
		color: '#8e8e93',
		fontSize: 12,
		marginBottom: 4,
	},
	dayNameActive: {
		color: '#aaccee',
	},
	dayNumber: {
		color: '#ffffff',
		fontSize: 16,
		fontWeight: 'bold',
	},
	dayNumberActive: {
		color: '#ffffff',
	},
	sectionHeader: {
		color: '#ffffff',
		fontSize: 14,
		fontWeight: 'bold',
		marginBottom: 12,
		marginLeft: 4,
		opacity: 0.8,
	},
	mainCardContainer: {
		marginBottom: 24,
		borderRadius: 24,
		shadowColor: UCI_BLUE,
		shadowOffset: { width: 0, height: 8 },
		shadowOpacity: 0.4,
		shadowRadius: 12,
		elevation: 8,
	},
	mainCard: {
		borderRadius: 24,
		padding: 24,
		borderWidth: 1,
		borderColor: 'rgba(255,255,255,0.1)',
	},
	cardHeaderRow: {
		flexDirection: 'row',
		justifyContent: 'space-between',
		marginBottom: 16,
	},
	badge: {
		backgroundColor: 'rgba(253, 200, 47, 0.2)', // Gold transparent
		paddingHorizontal: 10,
		paddingVertical: 4,
		borderRadius: 8,
	},
	badgeText: {
		color: UCI_GOLD,
		fontSize: 10,
		fontWeight: '800',
	},
	mainCardTitle: {
		color: '#ffffff',
		fontSize: 26,
		fontWeight: 'bold',
		marginBottom: 4,
	},
	mainCardSubtitle: {
		color: '#ccc',
		fontSize: 16,
		marginBottom: 20,
	},
	cardFooter: {
		flexDirection: 'row',
		justifyContent: 'space-between',
		alignItems: 'center',
	},
	metaRow: {
		flexDirection: 'row',
		alignItems: 'center',
		gap: 6,
	},
	metaText: {
		color: '#ccc',
		fontSize: 14,
	},
	startBtn: {
		flexDirection: 'row',
		alignItems: 'center',
		backgroundColor: UCI_GOLD,
		paddingHorizontal: 16,
		paddingVertical: 8,
		borderRadius: 20,
		gap: 4,
	},
	startBtnText: {
		color: UCI_BLUE,
		fontWeight: 'bold',
		fontSize: 12,
	},
	supplementsContainer: {
		flexDirection: 'row',
		justifyContent: 'space-between',
		gap: 12,
		marginBottom: 30,
	},
	supplementCard: {
		flex: 1,
		backgroundColor: '#1c1c1e',
		borderRadius: 16,
		padding: 16,
		alignItems: 'center',
		justifyContent: 'center',
		gap: 8,
	},
	supplementTitle: {
		color: '#fff',
		fontWeight: '600',
		fontSize: 12,
		textAlign: 'center',
	},
	supplementTime: {
		color: '#8e8e93',
		fontSize: 12,
	},
});