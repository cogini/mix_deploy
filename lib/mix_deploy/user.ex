defmodule MixDeploy.User do
  @moduledoc "Get information about OS users and groups"

  @typep name_id() :: {String.t(), non_neg_integer}
  @typep os_type :: {atom, atom}

  @doc "Get user and group of current user from OS id command"
  @spec get_id() :: {user :: name_id(), group :: name_id(), groups :: [name_id()]}
  def get_id do
    {data, 0} = System.cmd("id", [])

    [[user], [group], groups] =
      for pair <- String.split(String.trim(data), " ") do
        [_name, pairs] = String.split(pair, "=")

        for pair <- String.split(pairs, ",") do
          [num, name] = Regex.run(~R/^(\d+)\(([a-zA-Z1-9_.]+)\)$/, pair, capture: :all_but_first)
          {name, String.to_integer(num)}
        end
      end

    {user, group, groups}
  end

  @doc "Get uid for user"
  @spec get_uid(String.t()) :: non_neg_integer
  def get_uid(name) do
    get_uid(:os.type(), name)
  end

  @spec get_uid(os_type(), String.t()) :: non_neg_integer
  defp get_uid({:unix, :linux}, name) do
    {:ok, info} = get_user_info(name)
    info.uid
  end

  defp get_uid({:unix, :darwin}, name) do
    {:ok, uid} = dscl_read("/Users/#{name}", "PrimaryGroupID")
    String.to_integer(uid)
  end

  @doc "Get gid for group"
  @spec get_gid(String.t()) :: non_neg_integer
  def get_gid(name) do
    get_gid(:os.type(), name)
  end

  @spec get_gid(os_type(), String.t()) :: non_neg_integer
  defp get_gid({:unix, :linux}, name) do
    {:ok, info} = get_user_info(name)
    info.uid
  end

  defp get_gid({:unix, :darwin}, name) do
    {:ok, gid} = dscl_read("/Groups/#{name}", "PrimaryGroupID")
    String.to_integer(gid)
  end

  @doc "Get OS user info from /etc/passwd"
  @spec get_user_info(binary) :: {:ok, map}
  def get_user_info(name) do
    {:ok, record} = get_passwd_record(:os.type(), name)
    # "jake:x:1003:1005:ansible-jake:/home/jake:/bin/bash\n"
    [name, pw, uid, gid, gecos, home, shell] = String.split(String.trim(record), ":")

    {:ok,
     %{
       user: name,
       password: pw,
       uid: String.to_integer(uid),
       gid: String.to_integer(gid),
       gecos: gecos,
       home: home,
       shell: shell
     }}
  end

  @doc "Get OS group info from /etc/group"
  @spec get_group_info(binary) :: {:ok, map}
  def get_group_info(name) do
    {:ok, record} = get_group_record(:os.type(), name)
    # "wheel:x:10:jake,foo\n"
    [name, pw, gid, members] = String.split(String.trim(record), ":")
    members = parse_group_members(members)
    {:ok, %{name: name, password: pw, gid: String.to_integer(gid), members: members}}
  end

  @spec get_passwd_record({atom, atom}, String.t()) :: {:ok, String.t()}
  defp get_passwd_record({:unix, :linux}, name) do
    {data, 0} = System.cmd("getent", ["passwd", name])
    {:ok, data}
  end

  defp get_passwd_record({:unix, :darwin}, name) do
    path = "/Users/#{name}"

    values =
      for key <- ["UniqueID", "PrimaryGroupID", "RealName", "NFSHomeDirectory", "UserShell"] do
        {:ok, value} = dscl_read(path, key)
        value
      end

    {:ok, Enum.join([name, "x"] ++ values, ":") <> "\n"}
  end

  @spec get_group_record({atom, atom}, String.t()) :: {:ok, String.t()}
  defp get_group_record({:unix, :linux}, name) do
    {record, 0} = System.cmd("getent", ["group", name])
    {:ok, record}
  end

  defp get_group_record({:unix, :darwin}, name) do
    path = "/Groups/#{name}"
    {:ok, gid} = dscl_read(path, "PrimaryGroupID")
    {:ok, members} = dscl_read(path, "GroupMembership")
    members = dscl_format_group_members(members)
    record = Enum.join([name, "x", gid, members], ":") <> "\n"
    {:ok, record}
  end

  @doc "Call macOS dscl command to read information"
  @spec dscl_read(String.t(), String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def dscl_read(path, key) do
    case System.cmd("dscl", ["-q", ".", "-read", path, key]) do
      {data, 0} ->
        [_key, value] = Regex.split(~r/\s+/, String.trim(data), multiline: true, parts: 2)
        {:ok, value}

      _ ->
        {:error, :not_found}
    end
  end

  @spec dscl_format_group_members(String.t()) :: String.t()
  defp dscl_format_group_members(""), do: ""

  defp dscl_format_group_members(members) do
    Enum.join(Regex.split(~r/\s+/, String.trim(members), trim: true), ",")
  end

  @spec parse_group_members(String.t()) :: [String.t()]
  defp parse_group_members(""), do: []
  defp parse_group_members(members), do: String.split(members, ",")
end
