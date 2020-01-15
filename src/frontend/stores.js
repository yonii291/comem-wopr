import { writable } from 'svelte/store';
import { uuidv4 } from './utils';

function createGameStore() {
	const { set, subscribe, update } = writable(0);

	return {
    subscribe,

		start: ai => set({
      ai,
      board: Array(9).fill(null),
      finished: false,
      id: uuidv4()
    }),

    play: (cell, value) => update(g => {
      const board = g.board.slice();
      board[cell] = value;
      return { ...g, board };
    }),

		finish: () => update(g => ({ ...g, finished: true }))
	};
}

export const currentGame = createGameStore();