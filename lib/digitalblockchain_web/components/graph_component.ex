# lib/digitalblockchain_web/components/graph_component.ex
defmodule DigitalblockchainWeb.GraphComponent do
  use DigitalblockchainWeb, :live_component

  def render(assigns) do
    ~H"""
    <div id="graph-container" phx-hook="GraphHook">
      <svg width="1000" height="800"></svg>
    </div>
    """
  end
end
