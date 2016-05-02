defmodule ExContracts do
  @moduledoc """
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
  """

  defmodule Contract do
    defstruct precondition: nil, postcondition: nil, on_broken_contract: :raise, func_name: nil, func_args: nil, func_guards: nil, func_body: nil
  end

  defmacro __using__(_opts) do
    quote do
      import ExContracts

      Module.register_attribute(__MODULE__, :contracts_predicates, accumulate: true, persist: true)

      @contracts_compile_time_purge Application.get_env :excontracts, :compile_time_purge, false
      @on_broken_contracts :raise
      @before_compile ExContracts
      @on_definition  ExContracts
    end
  end

  defmacro __before_compile__(env) do
    mod = env.module
    predicates = Module.get_attribute(mod, :contracts_predicates) |> Enum.reverse

    contract_funcs = predicates
    |> Enum.map(&build_contract_function(&1, env))

    quote do
      unquote_splicing(contract_funcs)
    end
  end

  def __on_definition__(env, kind, name, args, guards, body) when kind in [:def, :defp] do
    mod = env.module
    if(Module.get_attribute(mod, :contracts_compile_time_purge) == false) do
      precond  = Module.get_attribute(mod, :require)
      postcond = Module.get_attribute(mod, :ensure)
      on_broken_contract = check_broken_contract_strategy(env)

      contract = %Contract{
        on_broken_contract: on_broken_contract,
        func_name:          name,
        func_args:          args,
        func_guards:        guards,
        func_body:          body,
      }

      Module.delete_attribute(mod, :on_broken_contract)
      if precond do
        contract = %{ contract | precondition: precond}
        Module.delete_attribute(mod, :require)
      end
      if postcond do
        contract = %{ contract | postcondition: postcond}
        Module.delete_attribute(mod, :ensure)
      end

      if precond || postcond do
        Module.put_attribute(mod, :contracts_predicates, contract)
      end
    end
    :ok
  end
  def __on_definition__(_env, _kind, _name, _args, _gaurds, _body), do: :ok

  defp check_broken_contract_strategy(env) do
    mod= env.module
    strategy = case Module.get_attribute(mod, :on_broken_contract) do
                 nil -> Module.get_attribute(mod, :on_broken_contracts)
                 val -> val
               end
    case strategy do
      val when val in [:raise, :error_tuple] -> val
      _ ->
        raise CompileError, file: env.file, line: env.line,
          description: "unknown value in @on_broken_contract/@on_broken_contracts attribute"
    end
  end

  defp build_contract_function(%Contract{}=contract, env) do
    mod = env.module
    Module.make_overridable(mod, [{contract.func_name, contract.func_args |> length}])

    body = build_contract_function_body(contract, env)

    if has_gaurds? contract do
      quote do
        def unquote(contract.func_name)(unquote_splicing(contract.func_args)) when unquote_splicing(contract.func_guards) do
          unquote(body)
        end
      end

    else
      quote do
        def unquote(contract.func_name)(unquote_splicing(contract.func_args)) do
          unquote(body)
        end
      end
    end
  end

  defmacro contract(predicate) do
    Macro.escape(predicate)
  end

  defp build_contract_function_body(contract, env) do
    mod = env.module
    body = quote do
      var!(result) = unquote(contract.func_body)
    end
    body = case contract.postcondition do
             nil -> body
             _   ->
               quote do
                 unquote(body)

                 if unquote(contract.postcondition) do
                   var!(result)

                 else
                   case unquote(contract.on_broken_contract) do
                     :raise       ->
                       raise ContractPostcondError,
                         mfa: {unquote(mod),
                               unquote(contract.func_name),
                               unquote(contract.func_args |> length)}
                     :error_tuple -> {:error, :contract_postcondition_not_met}
                   end
                 end
               end
           end
    body = case contract.precondition do
             nil -> body
             _   ->
               quote do
                 if unquote(contract.precondition) do
                   unquote(body)
                 else
                   case unquote(contract.on_broken_contract) do
                     :raise       ->
                       raise ContractPrecondError,
                         mfa: {unquote(mod), unquote(contract.func_name), unquote(contract.func_args |> length)}
                     :error_tuple -> {:error, :contract_precondition_not_met}
                   end
                 end
               end
           end
    body
  end

  defp has_gaurds?(%Contract{func_guards: nil}), do: false
  defp has_gaurds?(%Contract{func_guards: []}), do: false
  defp has_gaurds?(%Contract{func_guards: _}), do: true

  # defmacro require(predicate) do
  #   mod = __CALLER__.module
  #   Module.put_attribute(mod, :require, predicate)
  # end

  # defmacro ensure(predicate) do
  #   mod = __CALLER__.module
  #   Module.put_attribute(mod, :ensure, predicate)
  # end
end
