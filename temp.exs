numbers = [1,2,3,4,5]
target = 9
IO.inspect numbers
indexed = Enum.with_index(numbers)
IO.puts("Indexed: #{inspect indexed}")
sums = for {numberA, indexA} <- indexed do
  for {numberB, indexB} <- Enum.drop(indexed, indexA+1) do
    sum = numberA + numberB
    IO.puts "#{numberA} + #{numberB} = #{numberA + numberB}"
    {sum, indexA, indexB}
  end
end
sums = List.flatten(sums)
IO.puts ("Sums: #{inspect(sums)}")
result = Enum.find(sums, fn {sum, indexA, indexB} -> sum == target end)
IO.puts ("Result: #{inspect result}")
{target, indexA, indexB} = result
result = [indexA, indexB]
IO.puts(inspect result)
