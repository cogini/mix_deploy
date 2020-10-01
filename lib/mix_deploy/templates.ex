defmodule MixDeploy.Templates do
  @moduledoc """
  Template functions.

  These functions generate output files from templates.
  """

  # Name of app, used to get config from app environment
  @app :mix_deploy

  @doc "Generate file from template"
  @spec write_template(Keyword.t(), Path.t(), String.t()) :: :ok
  def write_template(vars, target_path, template) do
    write_template(vars, target_path, template, template)
  end

  @spec write_template(Keyword.t(), Path.t(), String.t(), Path.t()) :: :ok
  def write_template(vars, target_path, template, filename) do
    target_file = Path.join(target_path, filename)
    :ok = File.mkdir_p(target_path)
    template_path = Path.join(vars[:template_dir], "#{template}.eex")
    {:ok, data} = template_file(template_path, vars)
    :ok = File.write(target_file, data)
  end

  @doc "Evaluate template file with bindings"
  @spec template_file(String.t(), Keyword.t()) :: {:ok, String.t()} | {:error, term}
  def template_file(template_file, bindings \\ []) do
    {:ok, EEx.eval_file(template_file, bindings, trim: true)}
  rescue
    e ->
      {:error, {:template, e}}
  end

  @doc "Find template matching name and eval"
  @spec template_name(Path.t(), Keyword.t()) :: {:ok, String.t()} | {:error, term}
  def template_name(name, vars \\ []) do
    template_file = "#{name}.eex"
    override_file = Path.join(vars[:template_dir], template_file)

    if File.exists?(override_file) do
      template_file(override_file)
    else
      Application.app_dir(@app, ["priv", "templates"])
      |> Path.join(template_file)
      |> template_file(vars)
    end
  end
end
