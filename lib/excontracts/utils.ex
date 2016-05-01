defmodule ExContracts.Utils do
  def format_mfa({m, f, a}) do
    m = case m |> to_string do
          "Elixir." <> m -> m
          m -> m
        end
    "#{m}.#{f}/#{a}"
  end
end
