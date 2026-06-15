defmodule DigitalblockchainWeb.BlockLive do
  # In Phoenix v1.6+ apps, the line is typically: use MyAppWeb, :live_view
  use Phoenix.LiveView
  alias DigitalBlockchain.Blockchain
  require Logger

  def mount(_params, _session, socket) do
    genesis = GenServer.call(DigitalBlockchain.MKRAND, :rand)

    {:ok, assign(socket, genesis: genesis, blocks: [], selected_row: nil)}
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
        Logger.info("Rejected pasted text: #{text}")
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

    # Find the index of the selected block in socket.assigns.blocks
    index =
      Enum.find_index(socket.assigns.blocks, fn b -> b[:psi] == socket.assigns.selected_row end) ||
        0

    long_count = index + 1
    short_count = 0

    # Ingest memo into MKSTORM
    storm_record =
      DigitalBlockchain.MKSTORM.ingest(
        socket.assigns.selected_row,
        long_count,
        short_count,
        memo_text
      )

    Logger.info("MKSTORM record: #{inspect(storm_record)}")

    socket = assign(socket, blocks: blocks, selected_row: nil)
    {:noreply, socket}
  end

  # Generate blocks and retrieve any attachments from MKSTORM
  defp gen_populated_blocks(seed, num_blocks) do
    blocks =
      seed
      |> Blockchain.build(num_blocks)
      |> Enum.map(fn psi -> %{psi: psi} end)

    blocks =
      Enum.map(blocks, fn block ->
        records = DigitalBlockchain.MKSTORM.query(block[:psi])

        latest =
          records
          |> Enum.reverse()
          |> Enum.find(fn record ->
            Map.get(record, "payload") not in [nil, ""]
          end)

        case latest do
          nil ->
            block

          record ->
            Map.put(block, :memo_text, Map.get(record, "payload"))
        end
      end)

    Logger.info("Gen populated blocks:")
    IO.inspect(blocks)

    blocks
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
