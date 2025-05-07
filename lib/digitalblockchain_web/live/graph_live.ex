# lib/digitalblockchain_web/live/graph_live.ex
defmodule DigitalblockchainWeb.GraphLive do
  use DigitalblockchainWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="p-4">
      <h1 class="text-2xl font-bold mb-4">Logic Graph</h1>
      <.live_component module={DigitalblockchainWeb.GraphComponent} id="graph" />
    </div>
    """
  end
end
