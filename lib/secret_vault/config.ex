defmodule SecretVault.Config do
  @moduledoc """
  Keeps configuration for a `SecretVault.Storage`.
  """

  defstruct [:key, :env] ++ [
            cipher: SecretVault.Cipher.ErlangCrypto,
            cipher_opts: [],
            priv_path: nil,
            prefix: nil]

  @typedoc """
  A module implementing `SecretVault.EncryptionProvider` behaviour.
  """
  @type cipher :: module

  @typedoc """
  Options for specified provider.
  """
  @type cipher_opts :: Keyword.t()

  @typedoc """
  A module implementing `SecretVault.KeyDerivation`
  """
  @type key_derivation :: module

  @typedoc """
  Options for specified key derivation function.
  """
  @type key_derivation_opts :: Keyword.t()

  @typedoc """
  Priv path. Use it only when you wan't to specify it by hands.
  """
  @type priv_path :: String.t()

  @typedoc """
  Path prefix for your secrets in priv directory.

  It's usefull when you want to have more than one secret storage.
  Defaults to `secrets`.
  """
  @type prefix :: String.t()

  @typedoc """
  Simmetric key for cipher
  """
  @type key :: binary()

  @typedoc """
  Plain string password
  """
  @type password :: String.t()

  @type t :: %__MODULE__{
          cipher_opts: cipher_opts(),
          cipher: cipher(),
          key: key(),
          env: String.t(),
          priv_path: priv_path(),
          prefix: prefix()
        }

  # For Mix projects we can have this variable in compile-time
  # For non-Mix projects we can specify this variable in runtime
  # or work without `env` path at all
  env =
    if Code.ensure_loaded?(Mix) && function_exported?(Mix, :env, 0) do
      to_string Mix.env()
    else
      ""
    end

  @doc """
  Creates a struct that keeps configuration data for the storage.

  `app_name` is an OTP application name for the app you want to
  keep secrets for.
  """
  @spec new(app_name :: atom, [option]) :: t
        when option:
               {:cipher, cipher}
               | {:cipher_opts, cipher_opts}
               | {:key_derivation, key_derivation}
               | {:key_derivation_opts, key_derivation_opts}
               | {:priv_path, priv_path}
               | {:prefix, prefix}
               | {:password, password()}
               | {:key, key()}
               | {:env, String.t()}
  def new(app_name, opts \\ []) when is_atom(app_name) and is_list(opts) do
    key =
      cond do
        key = opts[:key] ->
          key

        password = opts[:password] ->
          key_derivation      = Keyword.get(opts, :key_derivation, SecretVault.KDFs.PBKDF2)
          key_derivation_opts = Keyword.get(opts, :key_derivation_opts, [])

          key_derivation.kdf(password, key_derivation_opts)

        true ->
          raise "No password or key specified"
      end

    opts =
      opts
      |> Keyword.put_new_lazy(:priv_path, fn ->
        to_string :code.priv_dir app_name
      end)
      |> Keyword.put_new(:prefix, "secrets")
      |> Keyword.put_new(:env, to_string unquote env)
      |> Keyword.put_new(:key, key)

    struct(__MODULE__, [{:key, key} | opts])
  end
end