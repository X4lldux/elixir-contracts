defmodule Tank do
  defstruct level: 0, max_level: 10, in_valve: :closed, out_valve: :closed

  use ExContracts
  @on_broken_contracts :raise

  @require contract not full?(tank) && tank.in_valve == :open && tank.out_valve == :closed
  @ensure  contract full?(result) && result.in_valve == :closed && result.out_valve == :closed
  @on_broken_contract :error_tuple
  def fill(tank) do
  def fill(tank) do
    %Tank{tank | level: 10, in_valve: :closed}
  end

  @require contract tank.in_valve == :closed && tank.out_valve == :open
  @ensure  contract empty?(result) && result.in_valve == :closed && result.out_valve == :closed
  def empty(tank) do
    %Tank{tank | level: 0, out_valve: :closedx}
  end

  def full?(tank) do
    tank.level == tank.max_level
  end

  def empty?(tank) do
    tank.level == 0
  end
end

defmodule TestTank do
  def run do
    tank = %Tank{level: 10}
    # tank = %Tank{level: 5, in_valve: :open}
    IO.inspect Tank.fill(tank)  # should fail

    # tank = %Tank{level: 10, out_valve: :open}
    tank = %Tank{level: 10, out_valve: :open}
    IO.inspect Tank.empty(tank)
  end
end
