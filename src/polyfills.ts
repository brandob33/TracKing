import 'react-native-get-random-values';
import { TextDecoder, TextEncoder } from 'text-encoding';
// import * as Crypto from 'expo-crypto'; // Removed manual patch

console.log('--- POLYFILLS EXECUTING ---');

// Polyfill Buffer
// @ts-ignore
global.Buffer = global.Buffer || require('buffer').Buffer;

// Polyfill for BigInt 
if (typeof BigInt === 'undefined') {
    console.log('!!! BigInt IS MISSING !!!');
} else {
    console.log('BigInt is available');
}

// Polyfill for TextEncoder/TextDecoder
if (typeof global.TextEncoder === 'undefined') {
    global.TextEncoder = TextEncoder;
}
if (typeof global.TextDecoder === 'undefined') {
    global.TextDecoder = TextDecoder;
}

// Verify Crypto
// @ts-ignore
if (global.crypto && global.crypto.getRandomValues) {
    console.log('Crypto.getRandomValues is available (via react-native-get-random-values)');
} else {
    console.error('!!! Crypto.getRandomValues IS MISSING !!!');
}

// Check if crypto.subtle exists (needed for some operations)
// @ts-ignore
if (global.crypto && global.crypto.subtle) {
    console.log('Crypto.subtle is available');
} else {
    console.log('Crypto.subtle is NOT available (may not be needed)');
}

console.log('--- POLYFILLS COMPLETE ---');
