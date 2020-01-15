import { writable } from 'svelte/store';
import { uuidv4 } from './utils';

function createGameStore() {
	const { set, subscribe, update } = writable(0);

	return {
    subscribe,

		start: ai => set({
      ai,
      board: Array(9).fill(null),
      id: uuidv4(),
      state: 'playing'
    }),

    play: (cell, value, newState) => update(g => {
      const board = g.board.slice();
      board[cell] = value;
      return { ...g, board, state: newState || g.state };
    })
	};
}

export const currentGame = createGameStore();