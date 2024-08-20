defmodule DigitalblockchainWeb.BlockLive do
  # In Phoenix v1.6+ apps, the line is typically: use MyAppWeb, :live_view
  use Phoenix.LiveView
  require DigitalBlockchain.Summary
  alias DigitalBlockchain.Blockchain
  require Logger

  @s3_bucket "digitalblockchain"
  @s3_url "https://fly.storage.tigris.dev"
  @s3_region "auto"

  def mount(_params, _session, socket) do
    genesis = GenServer.call(DigitalBlockchain.MKRAND, :rand)

    socket =
      allow_upload(
        socket,
        :photos,
        accept: ~w(.png .jpeg .jpg),
        max_entries: 3,
        max_file_size: 10_000_000,
        external: &presign_upload/2
      )

    {:ok, assign(socket, genesis: genesis, blocks: [], selected_row: nil)}
  end

  defp presign_upload(entry, socket) do
    config = %{
      region: @s3_region,
      access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
      secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")
    }

    {:ok, fields} =
      SimpleS3Upload.sign_form_upload(config, @s3_bucket,
        key: "test",
        content_type: entry.client_type,
        max_file_size: socket.assigns.uploads.photos.max_file_size,
        expires_in: :timer.hours(1)
      )

    metadata = %{
      uploader: "S3",
      key: "test",
      url: @s3_url,
      fields: fields
    }

    {:ok, metadata, socket}
  end

  def handle_event("new_genesis", _params, socket) do
    genesis = GenServer.call(DigitalBlockchain.MKRAND, :rand)
    {:noreply, assign(socket, genesis: genesis, blocks: [])}
  end

  def handle_event("gen", %{"num_blocks" => num_blocks}, socket) do
    blocks = gen_populated_blocks(socket.assigns.genesis, num_blocks)
    Logger.info("Live view received #{Enum.count(blocks)} blocks")
    {:noreply, assign(socket, :blocks, blocks)}
  end

  def handle_event("block-pasted", %{"pastedText" => text}, socket) do
    text = String.trim(text)
    Logger.info("Live view received pasted text: #{text}")

    socket =
      if Regex.match?(~r/\[<:([0-9A-Fa-f]+):>\]/, text) do
        assign(socket, genesis: text, blocks: [])
      else
        Logger.info("Regected pasted text: #{text}")
        socket
      end

    {:noreply, socket}
  end

  def handle_event("row-clicked", %{"rowid" => rowid}, socket) do
    Logger.info("row #{rowid} is clicked")
    {:noreply, assign(socket, selected_row: rowid)}
  end

  def handle_event("save-memo", %{"memo_text" => memo_text}, socket) do
    Logger.info(
      "Received textbox submission with value: #{memo_text} at #{socket.assigns.selected_row}"
    )

    # set memo in local copy
    blocks = update_memo(socket.assigns.selected_row, socket.assigns.blocks, memo_text)
    file_name = "#{psi_to_file_name(socket.assigns.selected_row)}.txt"
    :ok = File.write(file_name, memo_text)
    {:ok, local_file} = File.read(file_name)

    %{:status_code => 200} =
      ExAws.S3.put_object(@s3_bucket, file_name, local_file) |> ExAws.request!()

    :ok = File.rm(file_name)
    save_summary(socket.assigns.genesis, blocks)
    socket = assign(socket, blocks: blocks, selected_row: nil)
    {:noreply, socket}
  end

  def summary_file_name(psi) do
    "#{psi_to_file_name(psi)}.summary.json"
  end

  # Generate blocks and retrieve any attachments from DB
  defp gen_populated_blocks(seed, num_blocks) do
    blocks = Blockchain.build(seed, num_blocks)
    blocks = Enum.map(blocks, fn block -> %{:psi => block} end)

    # retrieve summary from DB
    summary_exists = s3_file_exists(@s3_bucket, summary_file_name(seed))

    blocks =
      if summary_exists do
        Logger.info("Retrieving summary file #{summary_file_name(seed)}")

        bucket_contents =
          ExAws.S3.get_object(@s3_bucket, summary_file_name(seed)) |> ExAws.request!()

        {:ok, summary} = Jason.decode(bucket_contents.body)
        Logger.info("Summary file retrieved")
        IO.inspect(summary)
        summary_map = Map.new(summary, fn element -> {element["psi"], element["memo_text"]} end)
        Logger.info("Summary map:")
        Logger.info(inspect(summary_map))

        blocks =
          Enum.map(blocks, fn block ->
            case Map.get(summary_map, block[:psi]) do
              nil -> block
              matched_item -> %{:psi => block[:psi], :memo_text => matched_item}
            end
          end)

        blocks
      else
        blocks
      end

    Logger.info("Gen populated blocks:")
    IO.inspect(blocks)
    blocks
  end

  def s3_file_exists(bucket, key) do
    case ExAws.S3.head_object(bucket, key) |> ExAws.request() do
      {:ok, _response} ->
        Logger.info("File #{key} exists in the bucket.")
        true

      {:error, {:http_error, 404, _}} ->
        Logger.info("File #{key} does not exist in the bucket.")
        false

      {:error, error} ->
        IO.puts("An error occurred: #{inspect(error)}")
        false
    end
  end

  def handle_info(:poll_db, socket) do
    Logger.info("Polling DB")

    file_exists =
      for block <- socket.assigns.blocks do
        {block, s3_file_exists(@s3_bucket, "#{psi_to_file_name(block)}.txt")}
      end

    Enum.map(file_exists, fn {psi, bool} ->
      if bool do
        Logger.info("#{psi} FILE")
      else
        Logger.info("#{psi}")
      end
    end)

    {:noreply, socket}
  end

  def psi_to_file_name(psi) do
    Logger.info("Converting psi #{psi}")
    [_, hex] = Regex.run(~r/\[<:([0-9A-Fa-f]+):>\]/, psi)
    Logger.info("Conversion: #{hex}")
    hex
  end

  def update_memo(psi, blocks, memo_text) do
    updated_blocks =
      Enum.map(blocks, fn block ->
        if block[:psi] == psi, do: %{psi: psi, memo_text: memo_text}, else: block
      end)

    Logger.info(
      "Updated block #{psi} in chain of size #{Enum.count(blocks)} with text: #{memo_text}"
    )

    Enum.map(updated_blocks, fn block -> Logger.info(inspect(block)) end)
    updated_blocks
  end

  def save_summary(genesis, blocks) do
    # save a JSON file representation of the blocks
    file_name = summary_file_name(genesis)
    # Get rid of blocks with no content
    blocks = Enum.reject(blocks, fn block -> block[:memo_text] == nil end)
    Logger.info("Encoding summary with #{Enum.count(blocks)}  size")
    {:ok, json_blocks} = Jason.encode(blocks)
    Logger.info("Encoded json:")
    Logger.info(inspect(json_blocks))
    :ok = File.write(file_name, json_blocks)
    {:ok, local_file} = File.read(file_name)
    Logger.info("Uploading JSON to #{file_name}")

    %{:status_code => 200} =
      ExAws.S3.put_object(@s3_bucket, file_name, local_file) |> ExAws.request!()

    Logger.info("Upload OK")
    :ok = File.rm(file_name)
  end

  def memo_form(assigns) do
    assigns = assign(assigns, form: to_form(%{"memo" => nil}))

    ~H"""
    <.form for={@form} multipart phx-submit="save-memo">
      <input type="text" name="memo_text" />
      <button type="submit" class="px-4 py-2 bg-blue-500 text-white rounded">
        Save
      </button>
    </.form>
    """
  end
end
