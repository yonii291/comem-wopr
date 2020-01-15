<script>
  import Game from './game.svelte';
  import { currentGame } from './stores';
  import { uuidv4 } from './utils';

  const play = ai => () => currentGame.start(ai);
</script>

<style>
</style>

{#if $currentGame}
  <Game />
{/if}

{#if !$currentGame || $currentGame.state !== 'playing'}
  <button type='button' on:click={play('random')}>Play against stupid</button>
  <button type='button' on:click={play('wopr')}>Play against the WOPR</button>
{/if}