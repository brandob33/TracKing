import { Ionicons } from '@expo/vector-icons';
import React, { useEffect, useRef, useState } from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';

export default function WorkoutTimer() {
    const [seconds, setSeconds] = useState(0);
    const [isActive, setIsActive] = useState(false);
    const intervalRef = useRef<NodeJS.Timeout | null>(null);

    useEffect(() => {
        if (isActive) {
            intervalRef.current = setInterval(() => {
                setSeconds((prev) => prev + 1);
            }, 1000);
        } else if (!isActive && intervalRef.current) {
            clearInterval(intervalRef.current);
        }
        return () => {
            if (intervalRef.current) clearInterval(intervalRef.current);
        };
    }, [isActive]);

    const toggleTimer = () => {
        setIsActive(!isActive);
    };

    const resetTimer = () => {
        setIsActive(false);
        setSeconds(0);
    };

    const formatTime = (totalSeconds: number) => {
        const mins = Math.floor(totalSeconds / 60);
        const secs = totalSeconds % 60;
        return `${mins < 10 ? '0' : ''}${mins}:${secs < 10 ? '0' : ''}${secs}`;
    };

    return (
        <View style={styles.container}>
            <View style={styles.displayContainer}>
                <Text style={styles.timeText}>{formatTime(seconds)}</Text>
            </View>
            <View style={styles.controls}>
                <TouchableOpacity style={[styles.button, styles.resetButton]} onPress={resetTimer}>
                    <Ionicons name="refresh" size={24} color="#CE1141" />
                </TouchableOpacity>

                <TouchableOpacity
                    style={[styles.button, styles.mainButton, isActive ? styles.stopButton : styles.startButton]}
                    onPress={toggleTimer}
                >
                    <Ionicons name={isActive ? "pause" : "play"} size={32} color="#ffffff" />
                </TouchableOpacity>

                {/* Placeholder for future lap feature or just invisible balancer */}
                <View style={[styles.button, { backgroundColor: 'transparent' }]} />
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        backgroundColor: '#1c1c1e',
        padding: 20,
        borderTopLeftRadius: 24,
        borderTopRightRadius: 24,
        borderTopWidth: 1,
        borderTopColor: '#2c2c2e',
    },
    displayContainer: {
        alignItems: 'center',
        marginBottom: 20,
    },
    timeText: {
        fontSize: 64,
        fontVariant: ['tabular-nums'],
        fontWeight: 'bold',
        color: '#ffffff',
        letterSpacing: 2,
    },
    controls: {
        flexDirection: 'row',
        justifyContent: 'space-between', // Change to space-between to spread reset and play
        alignItems: 'center',
        paddingHorizontal: 20,
    },
    button: {
        width: 64,
        height: 64,
        borderRadius: 32,
        alignItems: 'center',
        justifyContent: 'center',
    },
    resetButton: {
        backgroundColor: 'rgba(206, 17, 65, 0.15)',
    },
    mainButton: {
        width: 80,
        height: 80,
        borderRadius: 40,
        elevation: 4,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.3,
        shadowRadius: 4,
    },
    startButton: {
        backgroundColor: '#34C759',
    },
    stopButton: {
        backgroundColor: '#CE1141',
    },
});
