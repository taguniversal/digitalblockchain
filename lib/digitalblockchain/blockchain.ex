defmodule DigitalBlockchain.Blockchain do
  def build(seed, num_blocks) do
    blocks = GenServer.call(DigitalBlockchain.MKRAND, {:block, seed, num_blocks})
    blocks
  end

end
