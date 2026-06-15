defmodule DigitalBlockchain.MKSTORMTest do
  use ExUnit.Case, async: false

  alias DigitalBlockchain.MKSTORM

  test "ingests payload using public helper ingest/1" do
    payload = "humidity=44"
    record = MKSTORM.ingest(payload)

    assert is_map(record)
    assert record.originator != nil
    assert record.index != nil
    assert record.long_count > 0
    assert record.short_count >= 0
    assert is_binary(record.payload)
  end

  test "ingests payload using raw GenServer.call with string" do
    payload = "pressure=1013"
    record = GenServer.call(MKSTORM, payload)

    assert is_map(record)
    assert record.originator != nil
    assert record.index != nil
    assert record.long_count > 0
    assert record.short_count >= 0
    assert is_binary(record.payload)
  end
end
