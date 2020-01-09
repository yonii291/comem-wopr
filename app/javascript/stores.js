import { writable } from 'svelte/store';

export const currentGame = writable(Array(9).fill(null));