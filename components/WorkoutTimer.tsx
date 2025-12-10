import { Ionicons } from '@expo/vector-icons';
import React, { useEffect, useRef, useState } from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';

export default function WorkoutTimer() {
    const [seconds, setSeconds] = useState(0);
    const [isActive, setIsActive] = useState(false);
    const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

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
            {/* Left: Reset */}
            <TouchableOpacity style={styles.smallButton} onPress={resetTimer}>
                <Ionicons name="refresh" size={20} color="#CE1141" />
            </TouchableOpacity>

            {/* Middle: Timer */}
            <Text style={styles.timeText}>{formatTime(seconds)}</Text>

            {/* Right: Play/Pause */}
            <TouchableOpacity
                style={[styles.playButton, isActive ? styles.stopButton : styles.startButton]}
                onPress={toggleTimer}
            >
                <Ionicons name={isActive ? "pause" : "play"} size={20} color="#ffffff" />
            </TouchableOpacity>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        backgroundColor: '#1c1c1e',
        paddingVertical: 16,
        paddingHorizontal: 30,
        borderTopLeftRadius: 24,
        borderTopRightRadius: 24,
        borderTopWidth: 1,
        borderTopColor: '#2c2c2e',
    },
    timeText: {
        fontSize: 32,
        fontVariant: ['tabular-nums'],
        fontWeight: '700',
        color: '#ffffff',
        letterSpacing: 2,
    },
    smallButton: {
        width: 44,
        height: 44,
        borderRadius: 22,
        backgroundColor: 'rgba(206, 17, 65, 0.15)',
        alignItems: 'center',
        justifyContent: 'center',
    },
    playButton: {
        width: 44,
        height: 44,
        borderRadius: 22,
        alignItems: 'center',
        justifyContent: 'center',
    },
    startButton: {
        backgroundColor: '#34C759',
    },
    stopButton: {
        backgroundColor: '#CE1141',
    },
});
