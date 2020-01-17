<script>
  import { currentGame } from './stores';
  import { delay, uuidv4 } from './utils';

  let playing = false;
  let thinking = false;

  $: rows = Array(3).fill().map((_, i) => $currentGame.board.slice(i * 3, i * 3 + 3));

  const play = cell => async () => {
    if (playing || thinking) {
      return;
    }

    playing = true;
    try {
      const res = await fetch('/api/actions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          cell,
          ai: $currentGame.ai,
          game: $currentGame.id,
          number: $currentGame.board.reduce((memo, cell) => memo + (cell ? 1 : 0), 1)
        })
      });

      if (res.status !== 201) {
        playing = false;
        return;
      }

      const body = await res.json();
      currentGame.play(cell, 'X', body.state !== 'playing' ? body.state : undefined);

      playing = false;
      if (body.enemyCell !== undefined) {
        thinking = true;
        await delay(Math.random() * 1000);
        currentGame.play(body.enemyCell, 'O', body.state);
        thinking = false;
      }
    } catch (err) {
      playing = false;
      thinking = false;
      console.warn(err);
    }
  }
</script>

<style>
  table {
    border-collapse: collapse;
    cursor: pointer;
    font-family: "Lucida Console", Monaco, monospace;
  }
  table td {
    border: 1px solid black;
    text-align: center;
    vertical-align: middle;
    font-size: 4em;
    width: 1em;
    height: 1em;
  }
  table td:hover {
    background-color: #eeeeee;
  }
  table tr:first-child td {
    border-top: 0;
  }
  table tr:last-child td {
    border-bottom: 0;
  }
  table tr td:first-child {
    border-left: 0;
  }
  table tr td:last-child {
    border-right: 0;
  }
  .not-played span {
    visibility: hidden;
  }
  strong {
    font-weight: bold;
  }
</style>

<div class='d-flex justify-content-center'>
  <table class='mt-5'>
    {#each rows as row, rowIndex}
      <tr>
        {#each row as cell, columnIndex}
          <td class={cell ? 'played' : 'not-played'} on:click={play(rowIndex * 3 + columnIndex)}><span>{cell || '•'}</span></td>
        {/each}
      </tr>
    {/each}
  </table>
</div>

<p class='lead text-center mt-4'>
  {#if thinking}
    Thinking...
  {:else if playing}
    Submitting your move...
  {:else if $currentGame.state === 'playing'}
    Your turn.
  {:else if $currentGame.state === 'win'}
    <strong>You win!</strong>
  {:else if $currentGame.state === 'lose'}
    <strong>You lose.</strong>
  {:else if $currentGame.state === 'draw'}
    How about a nice game of chess?
  {/if}
</p>