Code.require_file "../../test_helper.exs", __DIR__

defmodule Mix.Tasks.App.StartTest do
  use MixTest.Case

  defmodule CustomApp do
    def project do
      [app: :app_start_sample, version: "0.1.0"]
    end
  end

  defmodule WrongElixirProject do
    def project do
      [ app: :error, version: "0.1.0", elixir: "~> 0.8.1" ]
    end
  end

  test "recompiles project if elixir version changed" do
    in_fixture "no_mixfile", fn ->
      Mix.Tasks.Compile.run []
      purge [A, B, C]

      assert_received { :mix_shell, :info, ["Compiled lib/a.ex"] }
      assert System.version == Mix.Deps.Lock.elixir_vsn

      # There is not much we can do, we need to wait a second
      # otherwise touching the file is not picked up by the compiler
      :timer.sleep(1000)

      Mix.Task.clear
      File.write!("ebin/.compile.lock", "the_past")
      File.touch("ebin/.compile.lock",   { { 2010, 1, 1 }, { 0, 0, 0 } })

      Mix.Tasks.App.Start.run ["--no-start"]
      assert_received { :mix_shell, :info, ["Compiled lib/a.ex"] }
    end
  end

  test "compiles and starts the project" do
    Mix.Project.push CustomApp

    in_fixture "no_mixfile", fn ->
      assert_raise Mix.Error, fn ->
        Mix.Tasks.App.Start.run ["--no-compile"]
      end

      Mix.Tasks.App.Start.run ["--no-start"]
      assert File.regular?("ebin/Elixir.A.beam")
      assert File.regular?("ebin/app_start_sample.app")
      refute List.keyfind(:application.loaded_applications, :app_start_sample, 0)

      Mix.Tasks.App.Start.run []
      assert List.keyfind(:application.loaded_applications, :app_start_sample, 0)
    end
  after
    Mix.Project.pop
  end

  test "validates the Elixir version requirement" do
    Mix.Project.push WrongElixirProject

    in_fixture "no_mixfile", fn ->
      error = assert_raise Mix.ElixirVersionError, fn ->
        Mix.Tasks.App.Start.run ["--no-start"]
      end

      assert error.message =~ %r/ to run :error /
    end
  after
    purge [A, B, C]
    Mix.Project.pop
  end

  test "does not validate the Elixir version requirement when disabled" do
    Mix.Project.push WrongElixirProject

    in_fixture "no_mixfile", fn ->
      Mix.Tasks.App.Start.run ["--no-start", "--no-elixir-version-check"]
    end
  after
    purge [A, B, C]
    Mix.Project.pop
  end
end
