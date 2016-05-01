defmodule ExContracts do
  defmodule Contract do
    defstruct precondition: nil, postcondition: nil, func_name: nil, func_args: nil, func_guards: nil, func_body: nil
  end

  defmacro __using__(_opts) do
    quote do
      import ExContracts

      Module.register_attribute(__MODULE__, :contract_predicates, accumulate: true, persist: true)

      @contracts_compile_time_purge Application.get_env :excontracts, :compile_time_purge, false
      @before_compile ExContracts
      @on_definition  ExContracts
    end
  end

  defmacro __before_compile__(env) do
    mod = env.module
    predicates = Module.get_attribute(mod, :contract_predicates) |> Enum.reverse

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

      contract = %Contract{
        func_name:   name,
        func_args:   args,
        func_guards: guards,
        func_body:   body,
      }

      if precond do
        contract = %{ contract | precondition: precond}
        Module.delete_attribute(mod, :require)
      end
      if postcond do
        contract = %{ contract | postcondition: postcond}
        Module.delete_attribute(mod, :ensure)
      end

      if precond || postcond do
        Module.put_attribute(mod, :contract_predicates, contract)
      end
    end
    :ok
  end
  def __on_definition__(_env, _kind, _name, _args, _gaurds, _body), do: :ok

  defp build_contract_function(%Contract{}=contract, env) do
    mod = env.module
    Module.make_overridable(mod, [{contract.func_name, contract.func_args |> length}])

    body = quote do
      unless unquote(contract.precondition), do: raise "Precondition not met: blame the client"
      var!(result) = unquote(contract.func_body)
      unless unquote(contract.postcondition), do: raise "Postcondition not met: blame yourself"

      var!(result)
    end

    if contract.func_guards |> length > 0 do
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

  # defmacro require(predicate) do
  #   mod = __CALLER__.module
  #   Module.put_attribute(mod, :require, predicate)
  # end

  # defmacro ensure(predicate) do
  #   mod = __CALLER__.module
  #   Module.put_attribute(mod, :ensure, predicate)
  # end
end
