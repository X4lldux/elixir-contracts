Contracts
=========

Design by Contract for Elixir


Usage
======

```elixir
defmodule Example do
  use Contracts

  @require x > 0
  @ensure (result * result) <= x && (result+1) * (result+1) > x
  def sqrt(x) do
    :math.sqrt(x)
  end
end
```
