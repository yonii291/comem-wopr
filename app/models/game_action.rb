class GameAction
  include ActiveModel::Validations

  attr_accessor :cell, :game, :number

  validates :cell, presence: true, numericality: { integer: true, greater_than_or_equal_to: 0, smaller_than_or_equal_to: 8 }
  validates :game, presence: true
  validates :number, presence: true, numericality: { integer: true, greater_than_or_equal_to: 1, smaller_than_or_equal_to: 9 }

  def initialize(params)
    @cell = params[:cell]
    @game = params[:game]
    @number = params[:number]
  end

  def as_json(options)
    {
      cell: @cell,
      game: @game,
      number: @number
    }
  end
end