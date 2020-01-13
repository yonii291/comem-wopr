class RandomAi < Ai
  def play board_data, player
    board_data.each_with_index.reduce([]){ |memo,(v,i)| v == '-' ? memo + [i] : memo }.shuffle.first
  end
end