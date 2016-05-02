ExContracts
=========

Provides support for Design by Contract technique Elixir.

Add `use ExContracts` to your module and then add `@require conntract` and/or `@ensure contract` attributes before
your functions. That additionally "contract" keyword in attributes is required (because of the limitations of
attributes and macros).

This modules adds some magic and it is imperative you know what's going on and how it works. Seriously! DO NOT USE IT
**unless** you understand what it does! All magic in code can be disastrous unless it's demystified.

## Usage

```elixir
defmodule Example do
  use ExContracts

  @on_broken_contracts :raise # can be omitted, default value (:raise) will be used

  @require contract x > 0
  @ensure contract (result * result) <= x && (result+1) * (result+1) > x
  @on_broken_contract :error_tuple # can be omitted, value from _@on_broken_contracts_ will be used
  def sqrt(x) do
    :math.sqrt(x)
  end
end
```

`@require` and `@ensure` attributes are used to "tag" a function with a contract. Only first, second or both at the
same time can be used. `@require` is used to define pre-condition and `@ensure` to define post-condition. Both
conditions must be met to ensure validity of the contract. Both conditions are checked at runtime, each time your
function is called. Contract from `@require` is checked before your functions is executed, to check if client did not
broke the contract. All function arguments are available for contract condition. `@ensure` contract condition is
checked after your function is executed and additionally to function arguments, you also can use `result` variable
(which contains result of your function) to validate the contract.

By default, when a contract is broken, an exception is raised. Either `ContractPrecondError` or `ContractPostcondError`.
But by setting `@on_broken_contracts` (for per module setting) or `@on_broken_contract` (per function) to `:raise` or
`:error_tuple` you can choose how broken contracts are reported. When `:error_tuple` setting is used, function with a
broken contract will return `{:error, :contract_precondition_not_met}` or `{:error, :contract_postcondition_not_met}`.

Disabling contract checks can be done by setting `@contracts_compile_time_purge` attribute to `true`. This can be also
disabled for entire project by setting `:excontracts` application's environment key `:compile_time_purge` to false.
This disables on modifications of your functions.


## How it works

On compilation phase, each of your functions, that are "tagged" with a `@require` or `@ensure` attributes, are
transformed and a bunch of `if`s is added wrapping function's body. Those `if`s check if pre/post-conditions are met
and if contract was broken a final clauses will be executed that will either raise or return an error tuple instead of
the actual result of function body. If both conditions are met, function's result is returned without any change!
