defmodule ContractPrecondError do
  defexception mfa: ""

  def message(exception) do
    mfa = exception.mfa |> ExContracts.Utils.format_mfa
    "Contract precondition for #{mfa}, was not met"
  end
end

defmodule ContractPostcondError do
  defexception mfa: ""

  def message(exception) do
    mfa = exception.mfa |> ExContracts.Utils.format_mfa
    "Contract postcondition for #{mfa}, was not met"
  end
end
