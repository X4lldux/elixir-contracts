defmodule ExContracts do
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
      on_broken_contract = case Module.get_attribute(mod, :on_broken_contract) do
                             nil -> Module.get_attribute(mod, :on_broken_contracts)
                             val -> val
                           end
                           |> case do
                                val when val in [:raise, :error_tuple] -> val
                                _ ->
                                  raise CompileError, file: env.file, line: env.line,
                                    description: "unknown value in @on_broken_contract/@on_broken_contracts attribute"
                           end

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

  defp build_contract_function(%Contract{}=contract, env) do
    mod = env.module
    Module.make_overridable(mod, [{contract.func_name, contract.func_args |> length}])

    body = quote do
      if unquote(contract.precondition) do
        var!(result) = unquote(contract.func_body)

        if unquote(contract.postcondition) do
          var!(result)

        else
          case unquote(contract.on_broken_contract) do
            :raise       ->
              raise ContractPostcondError,
                mfa: {unquote(mod), unquote(contract.func_name), unquote(contract.func_args |> length)}
            :error_tuple -> {:error, :contract_postcondition_not_met}
          end
        end

      else
        case unquote(contract.on_broken_contract) do
          :raise       ->
            raise ContractPrecondError,
              mfa: {unquote(mod), unquote(contract.func_name), unquote(contract.func_args |> length)}
          :error_tuple -> {:error, :contract_precondition_not_met}
        end
      end
    end

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
