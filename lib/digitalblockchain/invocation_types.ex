defmodule DigitalBlockchain.Types do
  defmodule ExprFragment do
    defstruct [:target, :call, :args]
  end

  defmodule Definition do
    defstruct [
      :name,
      :source_list,
      :destination_list,
      :resolution
    ]
  end
end
