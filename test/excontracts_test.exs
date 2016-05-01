defmodule TestA do
  use ExContracts

  @require contract IO.inspect(a)
  def test_require(a, b), do: IO.inspect b

  @ensure contract IO.inspect(a) && result
  def test_ensure(a, b), do: IO.inspect b

  @require contract IO.inspect(a)
  @ensure contract IO.inspect(a) && result
  def test_require_ensure(a, b), do: IO.inspect b


  @require contract IO.inspect(a)
  def test_require_with_guard(a, b) when true, do: IO.inspect b

  @ensure contract IO.inspect(a) && result
  def test_ensure_with_guard(a, b) when true, do: IO.inspect b

  @require contract IO.inspect(a)
  @ensure contract IO.inspect(a) && result
  def test_require_ensure_with_guard(a, b) when true, do: IO.inspect b
end

defmodule TestB do
  use ExContracts
  @on_broken_contracts :error_tuple

  @require contract IO.inspect(a)
  def test_require(a, b), do: IO.inspect b

  @ensure contract IO.inspect(a) && result
  def test_ensure(a, b), do: IO.inspect b

  @require contract IO.inspect(a)
  @ensure contract IO.inspect(a) && result
  def test_require_ensure(a, b), do: IO.inspect b


  @require contract IO.inspect(a)
  def test_require_with_guard(a, b) when true, do: IO.inspect b

  @ensure contract IO.inspect(a) && result
  def test_ensure_with_guard(a, b) when true, do: IO.inspect b

  @require contract IO.inspect(a)
  @ensure contract IO.inspect(a) && result
  def test_require_ensure_with_guard(a, b) when true, do: IO.inspect b
end

defmodule ExContractsTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  test "`@require` contract is checked before function is run" do
    assert capture_io(fn -> TestA.test_require(true, :ok) end) == "true\n:ok\n"
    assert capture_io(fn -> TestA.test_require_with_guard(true, :ok) end) == "true\n:ok\n"

    assert Regex.match?(~r/^true\n:ok\n/,
      capture_io(fn -> TestA.test_require_ensure(true, :ok) end))
    assert Regex.match?(~r/^true\n:ok\n/,
      capture_io(fn -> TestA.test_require_ensure_with_guard(true, :ok) end))
  end

  test "when `@require` contract fails, function was already run" do
    assert capture_io(fn ->
      try do
        TestA.test_require(false, :ok)
      rescue
        _ -> nil
      end
    end) == "false\n"
    assert capture_io(fn ->
      try do
        TestA.test_require_with_guard(false, :ok)
      rescue
        _ -> nil
      end
    end) == "false\n"
  end

  test "`@ensure` contract is checked after function is run" do
    assert capture_io(fn -> TestA.test_ensure(true, :ok) end) == ":ok\ntrue\n"
    assert capture_io(fn -> TestA.test_ensure_with_guard(true, :ok) end) == ":ok\ntrue\n"

    assert Regex.match?(~r/:ok\ntrue\n$/,
      capture_io(fn -> TestA.test_require_ensure(true, :ok) end))
    assert Regex.match?(~r/:ok\ntrue\n$/,
      capture_io(fn -> TestA.test_require_ensure_with_guard(true, :ok) end))
  end

  test "when `@ensure` contract fails, function was already run" do
    assert capture_io(fn ->
      try do
        TestA.test_ensure(false, :ok)
      rescue
        _ -> nil
      end
    end) == ":ok\nfalse\n"
    assert capture_io(fn ->
      try do
        TestA.test_ensure_with_guard(false, :ok)
      rescue
        _ -> nil
      end
    end) == ":ok\nfalse\n"

    assert Regex.match?(~r/:ok\nfalse\n$/,
      capture_io(fn ->
        try do
          TestA.test_ensure(false, :ok)
        rescue
          _ -> nil
        end
      end))
    assert Regex.match?(~r/:ok\nfalse\n$/,
      capture_io(fn ->
        try do
          TestA.test_ensure_with_guard(false, :ok)
        rescue
          _ -> nil
        end
      end))
  end

  test "when contract fails and @on_broken_contracts is set to `:error_tuple` tuple is returned" do
    capture_io fn ->
      assert TestB.test_require(false, :ok) == {:error, :contract_precondition_not_met}
      assert TestB.test_require_with_guard(false, :ok) == {:error, :contract_precondition_not_met}
      assert TestB.test_ensure(false, :ok) == {:error, :contract_postcondition_not_met}
      assert TestB.test_ensure_with_guard(false, :ok) == {:error, :contract_postcondition_not_met}
    end
  end
end
